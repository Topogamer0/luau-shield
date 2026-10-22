//! Conditions: what a guard teaches us about untrusted values on each branch.

use super::calls::looks_like_validator;
use super::interp::{args_exprs, is_falsy_literal, string_literal, symbol_of, unwrap_expr};
use super::state::{Facts, Frame, Refinement, State};
use super::value::{Builtin, Checks, Func, Kind, SourceKind, Target, Value, check};
use super::{Analyzer, token_name};
use full_moon::ast::{BinOp, Call, Expression, FunctionCall, Index, Prefix, Suffix, UnOp, Var};
use full_moon::tokenizer::{Symbol, TokenReference};

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

/// A Lua pattern anchored at both ends (`^%w+$`).
fn anchored(pattern: &str) -> bool {
    pattern.starts_with('^') && pattern.ends_with('$') && !pattern.ends_with("%$")
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
    fn peek(
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

    pub(crate) fn apply_facts(&self, state: &mut State<'a>, facts: &Facts) {
        for (target, checks) in &facts.map {
            state.add_checks(target, *checks);
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

    /// Variables whose size/value/location is measured by `expr`.
    fn measure_roots(
        &self,
        frame: &Frame<'a>,
        state: &State<'a>,
        expr: &'a Expression,
    ) -> Vec<(Target, Measure)> {
        let expr = unwrap_expr(expr);
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
                            let mut out =
                                with(self.tainted_roots(frame, state, lhs), Measure::Distance);
                            out.extend(with(
                                self.tainted_roots(frame, state, rhs),
                                Measure::Distance,
                            ));
                            return out;
                        }
                        return with(self.tainted_roots(frame, state, inner), Measure::Abs);
                    }
                    if let Prefix::Name(token) = var.prefix() {
                        if let Some(id) = frame.lookup(&token_name(token)) {
                            return vec![(Target::Var(id), Measure::Abs)];
                        }
                    }
                }
                Vec::new()
            }
            _ => Vec::new(),
        }
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
        // luau-shield007 lock pattern: `if busy[player] then return end`.
        if let Expression::Var(Var::Expression(var)) = unwrap_expr(expr) {
            let suffixes: Vec<&'a Suffix> = var.suffixes().collect();
            if let Some((Suffix::Index(Index::Brackets { expression, .. }), init)) =
                suffixes.split_last()
            {
                let key = self.peek(frame, state, expression);
                if key.player_rel {
                    let mut base = super::compact(var.prefix());
                    for s in init {
                        base.push_str(&super::compact(*s));
                    }
                    if let Some(entry) = self.entry.as_mut() {
                        entry.lock_reads.insert(base);
                    }
                }
            }
        }
        Refinement {
            on_true,
            on_false: Facts::default(),
        }
    }

    fn refine_compare(
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
                typeof_arg(lhs),
                string_const(rhs),
                typeof_arg(rhs),
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
            // `Players:GetPlayerFromCharacter(inst.Parent) == player`: the
            // lookup result is server data, but it is computed from a client
            // Instance, and comparing it with a server value proves ownership.
            let mut r = Refinement::default();
            for (side, other) in [(lhs, &right), (rhs, &left)] {
                let literal = matches!(
                    other.kind,
                    Kind::Number(Some(_)) | Kind::Str(Some(_)) | Kind::Bool(Some(_)) | Kind::Nil
                );
                if literal || matches!(unwrap_expr(side), Expression::Var(Var::Name(_))) {
                    continue;
                }
                for root in self.tainted_roots(frame, state, side) {
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
        if !bare_var {
            // `inst.Parent == player.Character`, `inst:GetAttribute("Owner") == player.UserId`
            if matches!(cmp, Cmp::Eq | Cmp::Ne) && !is_literal && !matches!(other.kind, Kind::Nil) {
                for root in self.tainted_roots(frame, state, tainted_expr) {
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
            // `#name <= 20`, `(pos - root.Position).Magnitude < 10`
            let upper_on_true = matches!(cmp, Cmp::Lt | Cmp::Le);
            let upper_on_false = matches!(cmp, Cmp::Gt | Cmp::Ge);
            if upper_on_true || upper_on_false {
                for (target, measure) in self.measure_roots(frame, state, tainted_expr) {
                    let facts = match measure {
                        Measure::Length => check::LENGTH,
                        Measure::Abs => check::BOUNDS,
                        Measure::Distance => check::BOUNDS | check::OWNERSHIP,
                    };
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
                            Some(e) => !self.peek(frame, state, e).is_tainted(),
                            None => false,
                        };
                        if anchor_trusted {
                            if let Some(t) = recv_target {
                                on_true.add(t, check::OWNERSHIP | check::TYPE_INSTANCE);
                            }
                        }
                    }
                    "IsAncestorOf" => {
                        if !recv.is_tainted() {
                            if let Some(t) = args.first().and_then(|e| self.target_of(frame, e)) {
                                on_true.add(t, check::OWNERSHIP | check::TYPE_INSTANCE);
                            }
                        }
                    }
                    "match" | "find" if recv.is_tainted() => {
                        let pattern = args.first().and_then(|e| string_const(e));
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
                                    if let (Some(list), Some(item)) = (args.first(), args.get(1)) {
                                        if !self.peek(frame, state, list).is_tainted() {
                                            if let Some(t) = self.target_of(frame, item) {
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
                                        if args
                                            .get(1)
                                            .and_then(|e| string_const(e))
                                            .as_deref()
                                            .is_some_and(anchored)
                                        {
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
