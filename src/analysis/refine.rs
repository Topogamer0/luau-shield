//! Conditions: what a guard teaches us about untrusted values on each branch.

use super::calls::looks_like_validator;
use super::interp::{
    args_exprs, is_condition, is_falsy_literal, string_literal, symbol_of, unwrap_expr,
};
use super::state::{Expect, Facts, Frame, Lit, Refinement, State};
use super::value::{Builtin, Checks, Func, Kind, SourceKind, Target, Value, check};
use super::{Analyzer, token_name};
use full_moon::ast::{BinOp, Call, Expression, FunctionCall, Index, Prefix, Suffix, UnOp, Var};
use full_moon::tokenizer::{Symbol, TokenReference};
use std::rc::Rc;

#[derive(Clone, Copy, PartialEq, Eq)]
enum Cmp {
    Eq,
    Ne,
    Lt,
    Le,
    Gt,
    Ge,
}

impl Cmp {
    fn of(op: &BinOp) -> Option<Cmp> {
        Some(match op {
            BinOp::TwoEqual(_) => Cmp::Eq,
            BinOp::TildeEqual(_) => Cmp::Ne,
            BinOp::LessThan(_) => Cmp::Lt,
            BinOp::LessThanEqual(_) => Cmp::Le,
            BinOp::GreaterThan(_) => Cmp::Gt,
            BinOp::GreaterThanEqual(_) => Cmp::Ge,
            _ => return None,
        })
    }

    /// `a < b` is `b > a`.
    fn flip(self) -> Cmp {
        match self {
            Cmp::Lt => Cmp::Gt,
            Cmp::Le => Cmp::Ge,
            Cmp::Gt => Cmp::Lt,
            Cmp::Ge => Cmp::Le,
            other => other,
        }
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Measure {
    /// `#x`, `string.len(x)`: bounds the size.
    Length,
    /// `math.abs(x)`, `x.Magnitude`: bounds the value.
    Abs,
    /// A distance involving `x` (or its position): bounds it and proves location.
    Distance,
}

fn type_checks(name: &str) -> Checks {
    match name {
        "number" => check::TYPE_NUMBER,
        "string" => check::TYPE_STRING,
        "boolean" => check::TYPE_BOOLEAN,
        "Instance" => check::TYPE_INSTANCE,
        "table" => check::TYPE_TABLE,
        _ => check::TYPE_OTHER,
    }
}

/// A server value, or a client Instance whose ownership was already verified
/// (a valid anchor for `IsDescendantOf` / distance checks).
fn is_verified(value: &Value<'_>) -> bool {
    // While summarising a validation function, the other parameters are
    // placeholders for what the caller passes (usually server data).
    value
        .flows
        .iter()
        .all(|f| f.any(check::OWNERSHIP | check::TRUSTED) || f.source.kind == SourceKind::Probe)
}

/// A Lua pattern anchored at both ends (`^%w+$`).
fn anchored(pattern: &str) -> bool {
    pattern.starts_with('^') && pattern.ends_with('$') && !pattern.ends_with("%$")
}

/// A literal compared with a state expression (`"Playing"`, `3`, `true`, `nil`).
fn literal_of(expr: &Expression) -> Option<Lit> {
    match unwrap_expr(expr) {
        Expression::String(token) => string_literal(token).map(|s| Lit::Str(Rc::from(&*s))),
        Expression::Number(token) => super::interp::number_literal(&token.token().to_string())
            .map(|n| Lit::Num(Rc::from(n.to_string().as_str()))),
        Expression::Symbol(token) => match symbol_of(token) {
            Some(Symbol::True) => Some(Lit::Bool(true)),
            Some(Symbol::False) => Some(Lit::Bool(false)),
            Some(Symbol::Nil) => Some(Lit::Nil),
            _ => None,
        },
        _ => None,
    }
}

/// The state a call reads, named like the writes that change it:
/// `recv@Attr` for `recv:GetAttribute("Attr")`, `list@find` for
/// `table.find(list, x)`.
fn state_call_text(call: &FunctionCall) -> Option<String> {
    let (prefix, init, last) = split_call(call)?;
    match last {
        Call::MethodCall(method) if token_name(method.name()) == "GetAttribute" => {
            let attr = args_exprs(method.args())
                .first()
                .and_then(|e| string_const(e))?;
            let mut recv = super::compact(prefix);
            for s in &init {
                recv.push_str(&super::compact(*s));
            }
            Some(format!("{recv}@{attr}"))
        }
        Call::AnonymousCall(args) => {
            let is_find = matches!(prefix, Prefix::Name(t) if token_name(t) == "table")
                && matches!(init.as_slice(), [Suffix::Index(Index::Dot { name, .. })] if token_name(name) == "find");
            if !is_find {
                return None;
            }
            let list = args_exprs(args).into_iter().next()?;
            Some(format!("{}@find", super::compact(unwrap_expr(list))))
        }
        _ => None,
    }
}

fn is_nil(expr: &Expression) -> bool {
    matches!(unwrap_expr(expr), Expression::Symbol(t) if symbol_of(t) == Some(Symbol::Nil))
}

fn string_const(expr: &Expression) -> Option<String> {
    match unwrap_expr(expr) {
        Expression::String(token) => string_literal(token).map(|s| s.to_string()),
        _ => None,
    }
}

/// Parts of a call expression: prefix, suffixes before the final call, and the call.
fn split_call(call: &FunctionCall) -> Option<(&Prefix, Vec<&Suffix>, &Call)> {
    let suffixes: Vec<&Suffix> = call.suffixes().collect();
    let (last, init) = suffixes.split_last()?;
    match last {
        Suffix::Call(c) => Some((call.prefix(), init.to_vec(), c)),
        _ => None,
    }
}

/// `typeof(x)` / `type(x)`: returns `x`.
fn typeof_arg(expr: &Expression) -> Option<&Expression> {
    let Expression::FunctionCall(call) = unwrap_expr(expr) else {
        return None;
    };
    let (prefix, init, last) = split_call(call)?;
    if !init.is_empty() {
        return None;
    }
    let Prefix::Name(name) = prefix else {
        return None;
    };
    let name = token_name(name);
    if name != "typeof" && name != "type" {
        return None;
    }
    let Call::AnonymousCall(args) = last else {
        return None;
    };
    args_exprs(args).into_iter().next()
}

/// Every variable name mentioned in an expression.
fn collect_names<'e>(expr: &'e Expression, out: &mut Vec<&'e TokenReference>) {
    match expr {
        Expression::Parentheses { expression, .. }
        | Expression::TypeAssertion { expression, .. }
        | Expression::UnaryOperator { expression, .. } => collect_names(expression, out),
        Expression::BinaryOperator { lhs, rhs, .. } => {
            collect_names(lhs, out);
            collect_names(rhs, out);
        }
        Expression::Var(Var::Name(token)) => out.push(token),
        Expression::Var(Var::Expression(var)) => {
            collect_prefix(var.prefix(), out);
            for suffix in var.suffixes() {
                collect_suffix(suffix, out);
            }
        }
        Expression::FunctionCall(call) => {
            collect_prefix(call.prefix(), out);
            for suffix in call.suffixes() {
                collect_suffix(suffix, out);
            }
        }
        Expression::InterpolatedString(s) => {
            for e in s.expressions() {
                collect_names(e, out);
            }
        }
        _ => {}
    }
}

fn collect_prefix<'e>(prefix: &'e Prefix, out: &mut Vec<&'e TokenReference>) {
    match prefix {
        Prefix::Name(token) => out.push(token),
        Prefix::Expression(e) => collect_names(e, out),
        _ => {}
    }
}

fn collect_suffix<'e>(suffix: &'e Suffix, out: &mut Vec<&'e TokenReference>) {
    match suffix {
        Suffix::Index(Index::Brackets { expression, .. }) => collect_names(expression, out),
        Suffix::Call(Call::AnonymousCall(args)) => {
            for e in args_exprs(args) {
                collect_names(e, out);
            }
        }
        Suffix::Call(Call::MethodCall(m)) => {
            for e in args_exprs(m.args()) {
                collect_names(e, out);
            }
        }
        _ => {}
    }
}

impl<'a> Analyzer<'a> {
    /// Evaluates without side effects (no calls analysed, nothing reported).
    pub(crate) fn peek(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        expr: &'a Expression,
    ) -> Value<'a> {
        self.peek += 1;
        let v = self.eval(frame, state, expr);
        self.peek -= 1;
        v
    }

    /// The pattern string passed to `match`/`find`, also through a constant.
    fn pattern_of(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        expr: Option<&'a Expression>,
    ) -> Option<String> {
        let expr = expr?;
        if let Some(s) = string_const(expr) {
            return Some(s);
        }
        let value = self.peek(frame, state, expr);
        if value.is_tainted() {
            return None;
        }
        value.str_const().map(str::to_string)
    }

    pub(crate) fn apply_facts(&self, state: &mut State<'a>, facts: &Facts) {
        for (text, expect) in &facts.expects {
            state.expects.insert(text.clone(), expect.clone());
        }
        for (target, checks) in &facts.map {
            state.add_checks(target, *checks);
            // Verifying an Instance also verifies what was read from it
            // earlier (`local handle = tool.Handle` before checking `tool`).
            if checks & check::OWNERSHIP != 0 {
                let derived: Vec<Target> = state
                    .vars
                    .iter()
                    .filter(|(_, v)| v.origin.as_ref() == Some(target) && v.is_tainted())
                    .map(|(id, _)| Target::Var(*id))
                    .collect();
                for d in derived {
                    state.add_checks(&d, check::OWNERSHIP | check::TYPE_INSTANCE);
                }
            }
        }
    }

    /// The variable or field path an expression denotes.
    pub(crate) fn target_of(&self, frame: &Frame<'a>, expr: &'a Expression) -> Option<Target> {
        match unwrap_expr(expr) {
            Expression::Var(Var::Name(token)) => {
                let name = token_name(token);
                Some(Target::Var(
                    frame
                        .lookup(&name)
                        .unwrap_or_else(|| super::global_id(frame.file, &name)),
                ))
            }
            Expression::Var(Var::Expression(var)) => {
                let suffixes: Vec<&'a Suffix> = var.suffixes().collect();
                let (root, keys) = self.static_path(frame, var.prefix(), &suffixes)?;
                if keys.is_empty() {
                    Some(Target::Var(root))
                } else {
                    Some(Target::Path(root, keys.join(".").into()))
                }
            }
            _ => None,
        }
    }

    /// Local variables mentioned in `expr` whose value is untrusted.
    fn tainted_roots(
        &self,
        frame: &Frame<'a>,
        state: &State<'a>,
        expr: &'a Expression,
    ) -> Vec<Target> {
        let mut names = Vec::new();
        collect_names(expr, &mut names);
        let mut out: Vec<Target> = Vec::new();
        for token in names {
            let name = token_name(token);
            if let Some(id) = frame.lookup(&name) {
                if self.read_name(frame, state, &name).is_tainted() {
                    let t = Target::Var(id);
                    if !out.contains(&t) {
                        out.push(t);
                    }
                }
            }
        }
        out
    }

    /// `math.floor(x)` compared with `x`, or `x % n` compared with a number:
    /// returns `x`.
    fn integer_test(
        &self,
        frame: &Frame<'a>,
        a: &'a Expression,
        b: &'a Expression,
    ) -> Option<Target> {
        match unwrap_expr(a) {
            Expression::FunctionCall(call) => {
                let text = super::compact(call);
                let rounding = ["math.floor(", "math.ceil(", "math.round("]
                    .iter()
                    .any(|p| text.starts_with(p));
                if !rounding {
                    return None;
                }
                let (_, _, last) = split_call(call)?;
                let Call::AnonymousCall(args) = last else {
                    return None;
                };
                let inner = args_exprs(args).into_iter().next()?;
                let x = self.target_of(frame, inner)?;
                (self.target_of(frame, b)? == x).then_some(x)
            }
            Expression::BinaryOperator {
                lhs,
                binop: BinOp::Percent(_),
                rhs,
            } => {
                let numeric = |e: &Expression| matches!(unwrap_expr(e), Expression::Number(_));
                if numeric(rhs) && numeric(b) {
                    self.target_of(frame, lhs)
                } else {
                    None
                }
            }
            _ => None,
        }
    }

    /// The Instances the values of `targets` were read from.
    fn origins_of(&self, state: &State<'a>, targets: Vec<Target>) -> Vec<Target> {
        targets
            .iter()
            .filter_map(|t| match t {
                Target::Var(id) => state.vars.get(id).and_then(|v| v.origin.clone()),
                _ => None,
            })
            .collect()
    }

    /// `targets` plus the Instances they were read from.
    fn with_origins(&self, state: &State<'a>, targets: Vec<Target>) -> Vec<Target> {
        let mut out = targets.clone();
        for target in &targets {
            if let Target::Var(id) = target {
                if let Some(origin) = state.vars.get(id).and_then(|v| v.origin.clone()) {
                    if !out.contains(&origin) {
                        out.push(origin);
                    }
                }
            }
        }
        out
    }

    /// Is the value of this variable server data or a verified Instance?
    fn target_verified(&self, frame: &Frame<'a>, state: &State<'a>, target: &Target) -> bool {
        let Target::Var(id) = target else {
            return false;
        };
        let value = state.vars.get(id).cloned().or_else(|| {
            self.statics
                .get(&frame.file)
                .and_then(|s| s.get(id))
                .cloned()
        });
        value.is_none_or(|v| is_verified(&v))
    }

    /// `typeof(x)`, or a local holding it (`local kind = typeof(x)`): returns `x`.
    fn typeof_arg_of(
        &self,
        frame: &Frame<'a>,
        state: &State<'a>,
        expr: &'a Expression,
    ) -> Option<&'a Expression> {
        if let Expression::Var(Var::Name(token)) = unwrap_expr(expr) {
            let id = frame.lookup(&token_name(token))?;
            return typeof_arg(state.vars.get(&id)?.defined_by?);
        }
        typeof_arg(expr)
    }

    /// Variables whose size/value/location is measured by `expr`.
    fn measure_roots(
        &self,
        frame: &Frame<'a>,
        state: &State<'a>,
        expr: &'a Expression,
    ) -> Vec<(Target, Measure)> {
        let expr = unwrap_expr(expr);
        // `local distance = (a - b).Magnitude; if distance > 10 then return end`
        if let Expression::Var(Var::Name(token)) = expr {
            if let Some(id) = frame.lookup(&token_name(token)) {
                if let Some(defined) = state.vars.get(&id).and_then(|v| v.defined_by) {
                    if !std::ptr::eq(defined, expr) {
                        return self.measure_roots(frame, state, defined);
                    }
                }
            }
        }
        let with = |targets: Vec<Target>, m: Measure| {
            targets.into_iter().map(|t| (t, m)).collect::<Vec<_>>()
        };
        match expr {
            Expression::UnaryOperator {
                unop: UnOp::Hash(_),
                expression,
            } => match self.target_of(frame, expression) {
                Some(t) => vec![(t, Measure::Length)],
                None => with(
                    self.tainted_roots(frame, state, expression),
                    Measure::Length,
                ),
            },
            Expression::FunctionCall(call) => {
                let Some((prefix, init, last)) = split_call(call) else {
                    return Vec::new();
                };
                match last {
                    Call::AnonymousCall(args) => {
                        let callee = {
                            let mut s = match prefix {
                                Prefix::Name(t) => token_name(t),
                                _ => String::new(),
                            };
                            for suffix in &init {
                                if let Suffix::Index(Index::Dot { name, .. }) = suffix {
                                    s.push('.');
                                    s.push_str(&token_name(name));
                                }
                            }
                            s
                        };
                        let first = args_exprs(args).into_iter().next();
                        match (callee.as_str(), first) {
                            ("string.len" | "utf8.len", Some(e)) => {
                                match self.target_of(frame, e) {
                                    Some(t) => vec![(t, Measure::Length)],
                                    None => Vec::new(),
                                }
                            }
                            ("math.abs", Some(e)) => {
                                with(self.tainted_roots(frame, state, e), Measure::Abs)
                            }
                            _ => Vec::new(),
                        }
                    }
                    Call::MethodCall(method) => {
                        let name = token_name(method.name());
                        if name == "len" && init.is_empty() {
                            if let Prefix::Name(token) = prefix {
                                let n = token_name(token);
                                if let Some(id) = frame.lookup(&n) {
                                    return vec![(Target::Var(id), Measure::Length)];
                                }
                            }
                        }
                        if name == "DistanceFromCharacter" {
                            let mut out = Vec::new();
                            for e in args_exprs(method.args()) {
                                out.extend(with(
                                    self.tainted_roots(frame, state, e),
                                    Measure::Distance,
                                ));
                            }
                            return out;
                        }
                        Vec::new()
                    }
                    _ => Vec::new(),
                }
            }
            Expression::Var(Var::Expression(var)) => {
                let suffixes: Vec<&Suffix> = var.suffixes().collect();
                let Some((last, init)) = suffixes.split_last() else {
                    return Vec::new();
                };
                let is_magnitude = matches!(last, Suffix::Index(Index::Dot { name, .. }) if token_name(name) == "Magnitude");
                if !is_magnitude {
                    return Vec::new();
                }
                // `(a - b).Magnitude`: a distance; `v.Magnitude`: a length.
                if init.is_empty() {
                    if let Prefix::Expression(inner) = var.prefix() {
                        let inner = unwrap_expr(inner);
                        if let Expression::BinaryOperator { lhs, rhs, .. } = inner {
                            return self.distance_roots(frame, state, lhs, rhs);
                        }
                        return with(self.tainted_roots(frame, state, inner), Measure::Abs);
                    }
                    if let Prefix::Name(token) = var.prefix() {
                        if let Some(id) = frame.lookup(&token_name(token)) {
                            let mut out = vec![(Target::Var(id), Measure::Abs)];
                            // `local offset = target - root.Position; offset.Magnitude`
                            let defined = state.vars.get(&id).and_then(|v| v.defined_by);
                            if let Some(Expression::BinaryOperator {
                                lhs,
                                binop: BinOp::Minus(_),
                                rhs,
                            }) = defined.map(unwrap_expr)
                            {
                                out.extend(self.distance_roots(frame, state, lhs, rhs));
                            }
                            return out;
                        }
                    }
                }
                Vec::new()
            }
            _ => Vec::new(),
        }
    }

    /// `(a - b).Magnitude`: a distance only proves where `a` is when the other
    /// point is server data (or already verified).
    fn distance_roots(
        &self,
        frame: &Frame<'a>,
        state: &State<'a>,
        lhs: &'a Expression,
        rhs: &'a Expression,
    ) -> Vec<(Target, Measure)> {
        let mut roots = self.tainted_roots(frame, state, lhs);
        for root in self.tainted_roots(frame, state, rhs) {
            if !roots.contains(&root) {
                roots.push(root);
            }
        }
        let verified: Vec<bool> = roots
            .iter()
            .map(|r| self.target_verified(frame, state, r))
            .collect();
        let mut out = Vec::new();
        for (i, root) in roots.iter().enumerate() {
            let others_ok = verified.iter().enumerate().all(|(j, ok)| j == i || *ok);
            if others_ok {
                out.push((root.clone(), Measure::Distance));
            }
        }
        out
    }

    /// What `cond` teaches on its true and false branches.
    pub(crate) fn refine_condition(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        cond: &'a Expression,
    ) -> Refinement {
        let expr = unwrap_expr(cond);
        match expr {
            Expression::UnaryOperator {
                unop: UnOp::Not(_),
                expression,
            } => self.refine_condition(frame, state, expression).negate(),
            Expression::BinaryOperator { lhs, binop, rhs } => match binop {
                BinOp::And(_) => {
                    let a = self.refine_condition(frame, state, lhs);
                    let mut right_state = state.clone();
                    self.apply_facts(&mut right_state, &a.on_true);
                    let b = self.refine_condition(frame, &mut right_state, rhs);
                    Refinement {
                        on_true: a.on_true.clone().union(&b.on_true),
                        on_false: a.on_false.intersect(&a.on_true.clone().union(&b.on_false)),
                    }
                }
                BinOp::Or(_) => {
                    let a = self.refine_condition(frame, state, lhs);
                    let mut right_state = state.clone();
                    self.apply_facts(&mut right_state, &a.on_false);
                    let b = self.refine_condition(frame, &mut right_state, rhs);
                    Refinement {
                        on_true: a.on_true.intersect(&a.on_false.clone().union(&b.on_true)),
                        on_false: a.on_false.clone().union(&b.on_false),
                    }
                }
                _ => match Cmp::of(binop) {
                    Some(cmp) => self.refine_compare(frame, state, lhs, cmp, rhs),
                    None => Refinement::default(),
                },
            },
            Expression::FunctionCall(call) => self.refine_call(frame, state, call),
            Expression::Var(Var::Name(token)) => {
                // `local ok = isValid(x); if not ok then return end`
                let value = self.read_name(frame, state, &token_name(token));
                match value.defined_by {
                    Some(condition) if is_condition(condition) && self.condition_depth < 4 => {
                        self.condition_depth += 1;
                        let r = self.refine_condition(frame, state, condition);
                        self.condition_depth -= 1;
                        // The value itself may also prove something
                        // (`local item = rawget(ITEMS, id)`).
                        let own = self.refine_truthy(frame, state, expr);
                        Refinement {
                            on_true: r.on_true.union(&own.on_true),
                            on_false: r.on_false.union(&own.on_false),
                        }
                    }
                    _ => self.refine_truthy(frame, state, expr),
                }
            }
            Expression::Var(_) => self.refine_truthy(frame, state, expr),
            _ => Refinement::default(),
        }
    }

    /// `if x then`: lookups proven non-nil allow-list their key.
    fn refine_truthy(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        expr: &'a Expression,
    ) -> Refinement {
        let value = self.peek(frame, state, expr);
        let mut on_true = Facts::default();
        if let Some(witness) = &value.witness {
            on_true.add(witness.clone(), check::ALLOWLIST);
        }
        // luau-shield007 lock pattern: `if busy[player] then return end`,
        // `if debounce then return end`, `if not tool.Enabled then return end`.
        let mut on_false = Facts::default();
        if self.entry.is_some() {
            let text = super::compact(unwrap_expr(expr));
            on_true = on_true.union(&Facts::expect(text.as_str(), Expect::Truthy));
            on_false = Facts::expect(text.as_str(), Expect::Falsy);
            self.pending_lock_reads.push(text);
        }
        Refinement { on_true, on_false }
    }

    fn refine_compare(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        lhs: &'a Expression,
        cmp: Cmp,
        rhs: &'a Expression,
    ) -> Refinement {
        let mut r = self.refine_compare_values(frame, state, lhs, cmp, rhs);
        if !matches!(cmp, Cmp::Eq | Cmp::Ne) {
            return r;
        }
        // luau-shield007 state machines: `if state[player] ~= "Playing" then
        // return end` proves `state[player] == "Playing"` after the test.
        if self.entry.is_some() {
            let (subject, literal) = match (literal_of(lhs), literal_of(rhs)) {
                (None, Some(lit)) => (lhs, Some(lit)),
                (Some(lit), None) => (rhs, Some(lit)),
                _ => (lhs, None),
            };
            if let (Some(lit), Expression::Var(_)) = (literal, unwrap_expr(subject)) {
                let text = super::compact(unwrap_expr(subject));
                let equal = Facts::expect(text.as_str(), Expect::Eq(lit.clone()));
                let different = Facts::expect(text.as_str(), Expect::Ne(lit));
                let (yes, no) = if cmp == Cmp::Eq {
                    (equal, different)
                } else {
                    (different, equal)
                };
                r.on_true = r.on_true.union(&yes);
                r.on_false = r.on_false.union(&no);
            }
        }
        let bool_literal = |e: &Expression| match unwrap_expr(e) {
            Expression::Symbol(t) => match symbol_of(t) {
                Some(Symbol::True) => Some(true),
                Some(Symbol::False) => Some(false),
                _ => None,
            },
            _ => None,
        };
        let (other, literal) = match (bool_literal(lhs), bool_literal(rhs)) {
            (None, Some(b)) => (lhs, b),
            (Some(b), None) => (rhs, b),
            _ => return r,
        };
        // `x == true` is `x`, `x == false` is `not x`: `ALLOWED[k] == true`,
        // `part:IsDescendantOf(plot) == false`, `busy[player] == true`.
        let truthy = self.refine_condition(frame, state, other);
        // A call to a check returns a boolean: not `true` means `false`.
        let boolean = matches!(unwrap_expr(other), Expression::FunctionCall(_));
        let (holds, fails) = if literal {
            (truthy.on_true, truthy.on_false)
        } else {
            (truthy.on_false, truthy.on_true)
        };
        let fails = if boolean { fails } else { Facts::default() };
        let (on_true, on_false) = if cmp == Cmp::Eq {
            (holds, fails)
        } else {
            (fails, holds)
        };
        Refinement {
            on_true: r.on_true.union(&on_true),
            on_false: r.on_false.union(&on_false),
        }
    }

    fn refine_compare_values(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        lhs: &'a Expression,
        cmp: Cmp,
        rhs: &'a Expression,
    ) -> Refinement {
        // `x == nil` / `x ~= nil`
        if matches!(cmp, Cmp::Eq | Cmp::Ne) && (is_nil(lhs) || is_nil(rhs)) {
            let other = if is_nil(lhs) { rhs } else { lhs };
            let truthy = self.refine_condition(frame, state, other);
            return if cmp == Cmp::Eq {
                Refinement {
                    on_true: Facts::default(),
                    on_false: truthy.on_true,
                }
            } else {
                Refinement {
                    on_true: truthy.on_true,
                    on_false: Facts::default(),
                }
            };
        }
        // `typeof(x) == "number"`
        if matches!(cmp, Cmp::Eq | Cmp::Ne) {
            let pattern = match (
                self.typeof_arg_of(frame, state, lhs),
                string_const(rhs),
                self.typeof_arg_of(frame, state, rhs),
                string_const(lhs),
            ) {
                (Some(arg), Some(ty), _, _) | (_, _, Some(arg), Some(ty)) => Some((arg, ty)),
                _ => None,
            };
            if let Some((arg, ty)) = pattern {
                let mut facts = Facts::default();
                if let Some(target) = self.target_of(frame, arg) {
                    facts.add(target, type_checks(&ty));
                }
                return if cmp == Cmp::Eq {
                    Refinement {
                        on_true: facts,
                        on_false: Facts::default(),
                    }
                } else {
                    Refinement {
                        on_true: Facts::default(),
                        on_false: facts,
                    }
                };
            }
        }
        // `math.floor(x) ~= x` / `x % 1 ~= 0` reject NaN (and non-integers).
        if matches!(cmp, Cmp::Eq | Cmp::Ne) {
            if let Some(target) = self
                .integer_test(frame, lhs, rhs)
                .or_else(|| self.integer_test(frame, rhs, lhs))
            {
                let facts = Facts::single(target, check::NAN_SAFE | check::TYPE_NUMBER);
                return if cmp == Cmp::Eq {
                    Refinement {
                        on_true: facts,
                        on_false: Facts::default(),
                    }
                } else {
                    Refinement {
                        on_true: Facts::default(),
                        on_false: facts,
                    }
                };
            }
        }
        // `x == x` / `x ~= x` (NaN test)
        if matches!(cmp, Cmp::Eq | Cmp::Ne) {
            if let (Some(a), Some(b)) = (self.target_of(frame, lhs), self.target_of(frame, rhs)) {
                if a == b {
                    let facts = Facts::single(a, check::NAN_SAFE);
                    return if cmp == Cmp::Eq {
                        Refinement {
                            on_true: facts,
                            on_false: Facts::default(),
                        }
                    } else {
                        Refinement {
                            on_true: Facts::default(),
                            on_false: facts,
                        }
                    };
                }
            }
        }
        let left = self.peek(frame, state, lhs);
        let right = self.peek(frame, state, rhs);
        // While summarising `isInRange(value, min, max)`, every parameter is
        // a placeholder: `value >= min` compares two different parameters,
        // and the bound comes from the caller. Treat each side as checked
        // against the other.
        let only_probes = |v: &Value<'a>| {
            v.is_tainted() && v.flows.iter().all(|f| f.source.kind == SourceKind::Probe)
        };
        if only_probes(&left)
            && only_probes(&right)
            && left
                .flows
                .iter()
                .all(|a| right.flows.iter().all(|b| a.source.id != b.source.id))
        {
            let mut trusted_right = right.clone();
            trusted_right.flows.clear();
            let mut trusted_left = left.clone();
            trusted_left.flows.clear();
            let a = self.compare_facts(frame, state, lhs, cmp, trusted_right);
            let b = self.compare_facts(frame, state, rhs, cmp.flip(), trusted_left);
            return Refinement {
                on_true: a.on_true.union(&b.on_true),
                on_false: a.on_false.union(&b.on_false),
            };
        }
        let (tainted_expr, other, cmp) = if left.is_tainted() && !right.is_tainted() {
            (lhs, right, cmp)
        } else if right.is_tainted() && !left.is_tainted() {
            (rhs, left, cmp.flip())
        } else if !left.is_tainted() && !right.is_tainted() && matches!(cmp, Cmp::Eq | Cmp::Ne) {
            // `ALLOWED[x] == true`: a lookup proven truthy allow-lists its key.
            for (side, other) in [(&left, &right), (&right, &left)] {
                let truthy_literal = matches!(
                    other.kind,
                    Kind::Bool(Some(true)) | Kind::Number(Some(_)) | Kind::Str(Some(_))
                );
                if let (Some(witness), true) = (&side.witness, truthy_literal) {
                    let facts = Facts::single(witness.clone(), check::ALLOWLIST);
                    return if cmp == Cmp::Eq {
                        Refinement {
                            on_true: facts,
                            on_false: Facts::default(),
                        }
                    } else {
                        Refinement {
                            on_true: Facts::default(),
                            on_false: facts,
                        }
                    };
                }
            }
            // `Players:GetPlayerFromCharacter(inst.Parent) == player`: the
            // lookup result is server data, but it is computed from a client
            // Instance, and comparing it with a server value proves ownership.
            let mut r = Refinement::default();
            for (side, other) in [(lhs, &right), (rhs, &left)] {
                let literal = matches!(
                    other.kind,
                    Kind::Number(Some(_)) | Kind::Str(Some(_)) | Kind::Bool(Some(_)) | Kind::Nil
                );
                if literal {
                    continue;
                }
                let roots = if matches!(unwrap_expr(side), Expression::Var(Var::Name(_))) {
                    // `local owner = Players:GetPlayerFromCharacter(model)` ... `owner ~= player`
                    let target: Vec<Target> = self.target_of(frame, side).into_iter().collect();
                    self.origins_of(state, target)
                } else {
                    self.with_origins(state, self.tainted_roots(frame, state, side))
                };
                for root in roots {
                    let facts = check::OWNERSHIP | check::TYPE_INSTANCE;
                    if cmp == Cmp::Eq {
                        r.on_true.add(root, facts);
                    } else {
                        r.on_false.add(root, facts);
                    }
                }
            }
            return r;
        } else {
            return Refinement::default();
        };
        self.compare_facts(frame, state, tainted_expr, cmp, other)
    }

    /// Facts from `tainted_expr <cmp> other` where `other` is trusted.
    fn compare_facts(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        tainted_expr: &'a Expression,
        cmp: Cmp,
        other: Value<'a>,
    ) -> Refinement {
        let mut r = Refinement::default();
        let literal_type = match &other.kind {
            Kind::Number(_) => check::TYPE_NUMBER,
            Kind::Str(_) => check::TYPE_STRING,
            Kind::Bool(_) => check::TYPE_BOOLEAN,
            _ => 0,
        };
        let is_literal = matches!(
            other.kind,
            Kind::Number(Some(_)) | Kind::Str(Some(_)) | Kind::Bool(Some(_))
        );
        let direct = self.target_of(frame, tainted_expr);
        if let Some(target) = &direct {
            let ordered_type = literal_type & (check::TYPE_NUMBER | check::TYPE_STRING);
            match cmp {
                Cmp::Eq => r.on_true.add(
                    target.clone(),
                    check::ALLOWLIST | check::BOUNDS | check::NAN_SAFE | literal_type,
                ),
                Cmp::Ne => r.on_false.add(
                    target.clone(),
                    check::ALLOWLIST | check::BOUNDS | check::NAN_SAFE | literal_type,
                ),
                Cmp::Lt | Cmp::Le => {
                    r.on_true.add(
                        target.clone(),
                        check::UPPER | check::NAN_SAFE | ordered_type,
                    );
                    r.on_false.add(target.clone(), check::LOWER | ordered_type);
                }
                Cmp::Gt | Cmp::Ge => {
                    r.on_true.add(
                        target.clone(),
                        check::LOWER | check::NAN_SAFE | ordered_type,
                    );
                    r.on_false.add(target.clone(), check::UPPER | ordered_type);
                }
            }
        }
        let bare_var = matches!(unwrap_expr(tainted_expr), Expression::Var(Var::Name(_)));
        // `inst.Parent == player.Character`, `inst:GetAttribute("Owner") == player.UserId`,
        // or `owner == player.UserId` where `owner` was read from the Instance.
        if matches!(cmp, Cmp::Eq | Cmp::Ne) && !is_literal && !matches!(other.kind, Kind::Nil) {
            let roots = if bare_var {
                self.origins_of(state, direct.iter().cloned().collect())
            } else {
                self.with_origins(state, self.tainted_roots(frame, state, tainted_expr))
            };
            for root in roots {
                if Some(&root) == direct.as_ref() {
                    continue;
                }
                let facts = check::OWNERSHIP | check::TYPE_INSTANCE;
                if cmp == Cmp::Eq {
                    r.on_true.add(root, facts);
                } else {
                    r.on_false.add(root, facts);
                }
            }
        }
        // `#name <= 20`, `(pos - root.Position).Magnitude < 10`, `distance > 10`
        let upper_on_true = matches!(cmp, Cmp::Lt | Cmp::Le);
        let upper_on_false = matches!(cmp, Cmp::Gt | Cmp::Ge);
        if upper_on_true || upper_on_false {
            for (target, measure) in self.measure_roots(frame, state, tainted_expr) {
                let facts = match measure {
                    Measure::Length => check::LENGTH,
                    Measure::Abs => check::BOUNDS,
                    Measure::Distance => check::BOUNDS | check::OWNERSHIP,
                };
                let mut targets = vec![target];
                if measure == Measure::Distance {
                    targets = self.with_origins(state, targets);
                }
                for target in targets {
                    if upper_on_true {
                        r.on_true.add(target, facts | check::NAN_SAFE);
                    } else {
                        r.on_false.add(target, facts);
                    }
                }
            }
        }
        r
    }

    fn refine_call(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        call: &'a FunctionCall,
    ) -> Refinement {
        let guard = self.guard_facts(frame, state, call);
        let r = self.refine_call_checks(frame, state, call);
        let mut on_true = r.on_true.union(&guard);
        let mut on_false = r.on_false;
        // luau-shield007 state kept in an attribute or a list:
        // `if player:GetAttribute("Busy") then`, `if table.find(busy, player) then`.
        if let (Some(text), true) = (state_call_text(call), self.entry.is_some()) {
            on_true = on_true.union(&Facts::expect(text.as_str(), Expect::Truthy));
            on_false = on_false.union(&Facts::expect(text.as_str(), Expect::Falsy));
        }
        Refinement { on_true, on_false }
    }

    /// `if not Admins.isAdmin(player) then return end`: a permission guard
    /// (see `Config::is_guard`) called on the player who sent the request.
    /// Where it succeeded, every untrusted value is `PRIVILEGED`: findings on
    /// them are downgraded to `info` ("admin only").
    fn guard_facts(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        call: &'a FunctionCall,
    ) -> Facts {
        let mut facts = Facts::default();
        let Some((prefix, init, last)) = split_call(call) else {
            return facts;
        };
        let mut path: Vec<String> = Vec::new();
        if let Prefix::Name(t) = prefix {
            path.push(token_name(t));
        }
        for s in &init {
            if let Suffix::Index(Index::Dot { name, .. }) = s {
                path.push(token_name(name));
            }
        }
        let args = match last {
            Call::MethodCall(method) => {
                path.push(token_name(method.name()));
                args_exprs(method.args())
            }
            Call::AnonymousCall(args) => args_exprs(args),
            _ => return facts,
        };
        if path.is_empty() || !self.config.is_guard(&path) {
            return facts;
        }
        // The guard must test the sender (`player`, `player.UserId`), not a
        // player or id chosen by the client. Other arguments must be
        // constants (`hasPermission(player, "Ban")`): `isOwner(player, plot)`
        // checks who owns a plot, not who the player is.
        let values: Vec<Value<'a>> = args.iter().map(|e| self.peek(frame, state, e)).collect();
        let on_sender = values.iter().any(|v| v.player_rel && !v.is_tainted());
        let only_constants = values.iter().all(|v| {
            !v.is_tainted()
                && (v.player_rel
                    || matches!(
                        v.kind,
                        Kind::Str(Some(_)) | Kind::Number(Some(_)) | Kind::Bool(Some(_))
                    ))
        });
        if !on_sender || !only_constants {
            return facts;
        }
        self.guard = Some(super::compact(call));
        for (id, value) in &state.vars {
            if !value.deep_flows().is_empty() {
                facts.add(Target::Var(*id), check::PRIVILEGED);
            }
        }
        facts
    }

    fn refine_call_checks(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        call: &'a FunctionCall,
    ) -> Refinement {
        let mut on_true = Facts::default();
        let Some((prefix, init, last)) = split_call(call) else {
            return Refinement::default();
        };
        match last {
            Call::MethodCall(method) => {
                let name = token_name(method.name());
                let args: Vec<&'a Expression> = args_exprs(method.args());
                let recv_target = self.static_path(frame, prefix, &init).map(|(root, keys)| {
                    if keys.is_empty() {
                        Target::Var(root)
                    } else {
                        Target::Path(root, keys.join(".").into())
                    }
                });
                let recv = self.peek_suffixed(frame, state, prefix, &init);
                match name.as_str() {
                    "IsA" => {
                        if let Some(t) = recv_target {
                            on_true.add(t, check::TYPE_INSTANCE);
                        }
                    }
                    "GetAttribute" => {
                        // luau-shield007: `if player:GetAttribute("Busy") then return end`
                        if let (Some(attr), true) = (
                            args.first().and_then(|e| string_const(e)),
                            self.entry.is_some(),
                        ) {
                            let mut recv_text = super::compact(prefix);
                            for s in &init {
                                recv_text.push_str(&super::compact(*s));
                            }
                            self.pending_lock_reads.push(format!("{recv_text}@{attr}"));
                        }
                    }
                    "HasTag" => {
                        if recv.is_service("CollectionService") {
                            if let Some(t) = args.first().and_then(|e| self.target_of(frame, e)) {
                                on_true.add(t, check::TYPE_INSTANCE);
                            }
                        } else if let Some(t) = recv_target {
                            on_true.add(t, check::TYPE_INSTANCE);
                        }
                    }
                    "IsDescendantOf" => {
                        let anchor_trusted = match args.first() {
                            Some(e) => {
                                let anchor = self.peek(frame, state, e);
                                is_verified(&anchor)
                            }
                            None => false,
                        };
                        if anchor_trusted {
                            if let Some(t) = recv_target {
                                on_true.add(t, check::OWNERSHIP | check::TYPE_INSTANCE);
                            }
                        }
                    }
                    "IsAncestorOf" => {
                        if is_verified(&recv) {
                            if let Some(t) = args.first().and_then(|e| self.target_of(frame, e)) {
                                on_true.add(t, check::OWNERSHIP | check::TYPE_INSTANCE);
                            }
                        }
                    }
                    "match" | "find" if recv.is_tainted() => {
                        let pattern = self.pattern_of(frame, state, args.first().copied());
                        if let Some(t) = recv_target {
                            let mut facts = check::TYPE_STRING;
                            if pattern.as_deref().is_some_and(anchored) {
                                facts |= check::PATTERN;
                            }
                            on_true.add(t, facts);
                        }
                    }
                    _ => {
                        // Methods of tables: validation functions.
                        let mut handled = false;
                        if let Kind::Table(table) = &recv.kind {
                            if let Some(field) = table.fields.get(name.as_str()) {
                                for func in field.funcs() {
                                    if let Func::Closure(closure) = func {
                                        handled = true;
                                        if let Some(summary) = self.summary_of(&closure, state) {
                                            for (i, e) in args.iter().enumerate() {
                                                if let (Some(t), Some(c)) = (
                                                    self.target_of(frame, e),
                                                    summary.truthy.get(i + 1),
                                                ) {
                                                    on_true.add(t, *c);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        if !handled {
                            let mut path: Vec<String> = Vec::new();
                            if let Prefix::Name(t) = prefix {
                                path.push(token_name(t));
                            }
                            for s in &init {
                                if let Suffix::Index(Index::Dot { name, .. }) = s {
                                    path.push(token_name(name));
                                }
                            }
                            path.push(name.clone());
                            on_true = on_true.union(
                                &self.heuristic_validator(frame, state, &path, &name, &args),
                            );
                        }
                    }
                }
            }
            Call::AnonymousCall(args) => {
                let args: Vec<&'a Expression> = args_exprs(args);
                let callee = self.peek_suffixed(frame, state, prefix, &init);
                let mut path: Vec<String> = Vec::new();
                if let Prefix::Name(t) = prefix {
                    path.push(token_name(t));
                }
                for s in &init {
                    match s {
                        Suffix::Index(Index::Dot { name, .. }) => path.push(token_name(name)),
                        _ => path.clear(),
                    }
                }
                let last_name = path.last().cloned().unwrap_or_default();
                match &callee.kind {
                    Kind::Func(funcs) => {
                        for func in funcs.iter() {
                            match func {
                                Func::Builtin(Builtin::TableFind) => {
                                    // luau-shield007: `if table.find(busy, player) then return end`
                                    if let (Some(list), true) = (args.first(), self.entry.is_some())
                                    {
                                        self.pending_lock_reads.push(format!(
                                            "{}@find",
                                            super::compact(unwrap_expr(list))
                                        ));
                                    }
                                    if let (Some(list), Some(item)) = (args.first(), args.get(1)) {
                                        if !self.peek(frame, state, list).is_tainted() {
                                            if let Some(t) = self.target_of(frame, item) {
                                                on_true.add(t, check::ALLOWLIST);
                                            }
                                        }
                                    }
                                }
                                Func::Builtin(Builtin::Rawget) => {
                                    // `if rawget(ITEMS, id) then`: like `ITEMS[id]`.
                                    if let (Some(table), Some(key)) = (args.first(), args.get(1)) {
                                        if !self.peek(frame, state, table).is_tainted() {
                                            if let Some(t) = self.target_of(frame, key) {
                                                on_true.add(t, check::ALLOWLIST);
                                            }
                                        }
                                    }
                                }
                                Func::Builtin(Builtin::StringMatch | Builtin::StringFind) => {
                                    if let Some(t) =
                                        args.first().and_then(|e| self.target_of(frame, e))
                                    {
                                        let mut facts = check::TYPE_STRING;
                                        let pattern =
                                            self.pattern_of(frame, state, args.get(1).copied());
                                        if pattern.as_deref().is_some_and(anchored) {
                                            facts |= check::PATTERN;
                                        }
                                        on_true.add(t, facts);
                                    }
                                }
                                Func::Closure(closure) => {
                                    let closure = closure.clone();
                                    if let Some(summary) = self.summary_of(&closure, state) {
                                        let offset = usize::from(closure.is_method);
                                        for (i, e) in args.iter().enumerate() {
                                            if let (Some(t), Some(c)) = (
                                                self.target_of(frame, e),
                                                summary.truthy.get(i + offset),
                                            ) {
                                                on_true.add(t, *c);
                                            }
                                        }
                                    }
                                }
                                _ => {}
                            }
                        }
                    }
                    Kind::Validator(validator) if validator.constructor.is_none() => {
                        let validator = validator.clone();
                        on_true = on_true.union(&self.validator_facts(frame, &validator, &args));
                    }
                    _ => {
                        on_true = on_true.union(
                            &self.heuristic_validator(frame, state, &path, &last_name, &args),
                        );
                    }
                }
            }
            _ => {}
        }
        Refinement {
            on_true,
            on_false: Facts::default(),
        }
    }

    /// Custom sanitizers and unresolved functions named like validators.
    fn heuristic_validator(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        path: &[String],
        name: &str,
        args: &[&'a Expression],
    ) -> Facts {
        let mut facts = Facts::default();
        let configured = self
            .config
            .sanitizers
            .iter()
            .filter(|s| s.pattern.matches(path))
            .map(|s| s.checks)
            .reduce(|a, b| a | b);
        let checks = match configured {
            Some(c) => c,
            None if self.config.trust_unresolved_validators && looks_like_validator(name) => {
                check::VALIDATED
            }
            None => return facts,
        };
        for e in args {
            if self.peek(frame, state, e).is_tainted() {
                if let Some(t) = self.target_of(frame, e) {
                    facts.add(t, checks);
                }
            }
        }
        facts
    }

    fn peek_suffixed(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        prefix: &'a Prefix,
        suffixes: &[&'a Suffix],
    ) -> Value<'a> {
        self.peek += 1;
        let v = self
            .eval_suffixed(frame, state, prefix, suffixes.to_vec(), false)
            .into_iter()
            .next()
            .unwrap_or_default();
        self.peek -= 1;
        v
    }

    /// Records parameter facts at a return point while summarising a function.
    pub(crate) fn record_summary_return(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        expr: Option<&'a Expression>,
    ) {
        let Some(collector) = frame.summary.as_ref() else {
            return;
        };
        let params = collector.params.clone();
        let probe_checks = |state: &State<'a>| -> Vec<Checks> {
            params
                .iter()
                .map(|(var, probe)| {
                    state
                        .vars
                        .get(var)
                        .map(|v| {
                            v.flows
                                .iter()
                                .filter(|f| f.source.id == *probe)
                                .map(|f| f.checks)
                                .reduce(|a, b| a & b)
                                .unwrap_or(0)
                        })
                        .unwrap_or(0)
                })
                .collect()
        };
        let exit_now = probe_checks(state);
        let truthy_now = match expr {
            Some(e) if !is_falsy_literal(e) => {
                let r = self.refine_condition(frame, state, e);
                let mut s = state.clone();
                self.apply_facts(&mut s, &r.on_true);
                Some(probe_checks(&s))
            }
            _ => None,
        };
        let collector = frame.summary.as_mut().expect("summary collector");
        collector.exit = Some(match collector.exit.take() {
            None => exit_now,
            Some(prev) => prev.iter().zip(&exit_now).map(|(a, b)| a & b).collect(),
        });
        if let Some(truthy_now) = truthy_now {
            collector.may_return_truthy = true;
            collector.truthy = Some(match collector.truthy.take() {
                None => truthy_now,
                Some(prev) => prev.iter().zip(&truthy_now).map(|(a, b)| a & b).collect(),
            });
        }
    }
}
