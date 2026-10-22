//! Statements and expressions.

use super::state::{Frame, LoopCtx, State};
use super::value::{
    Builtin, Closure, Flow, Func, Kind, Obj, ObjClass, Table, Target, Value, check,
};
use super::{Analyzer, EntryKind, compact, global_id, token_name, var_id};
use crate::finding::Loc;
use full_moon::ast::{
    BinOp, Block, Call, Expression, Field, FunctionArgs, FunctionBody, Index, LastStmt, Prefix,
    Stmt, Suffix, UnOp, Var,
};
use full_moon::node::Node;
use full_moon::tokenizer::{Symbol, TokenReference, TokenType};
use std::collections::BTreeMap;
use std::rc::Rc;

/// A key used to index a value.
pub(crate) enum Key<'a> {
    Name(Rc<str>),
    Dynamic(Value<'a>, Option<Target>),
}

impl Key<'_> {
    pub fn name(&self) -> Option<&str> {
        match self {
            Key::Name(n) => Some(n),
            Key::Dynamic(..) => None,
        }
    }
}

/// Library tables that are globals in Roblox.
const LIBRARIES: &[&str] = &[
    "math",
    "string",
    "table",
    "task",
    "coroutine",
    "os",
    "Instance",
    "Vector3",
    "Vector2",
    "CFrame",
    "Color3",
    "UDim2",
    "UDim",
    "BrickColor",
    "TweenInfo",
    "NumberRange",
    "Ray",
    "Region3",
    "Rect",
    "NumberSequence",
    "ColorSequence",
    "PhysicalProperties",
    "Random",
    "OverlapParams",
    "RaycastParams",
    "DateTime",
    "utf8",
    "bit32",
    "buffer",
    "debug",
    "Enum",
    "Axes",
    "Faces",
    "NumberSequenceKeypoint",
    "ColorSequenceKeypoint",
    "Font",
    "Content",
    "SharedTable",
    "vector",
];

fn library_member(library: &str, member: &str) -> Builtin {
    use Builtin::*;
    match (library, member) {
        ("math", "clamp") => MathClamp,
        ("math", "min") => MathMin,
        ("math", "max") => MathMax,
        ("math", "abs") => MathAbs,
        ("math", "floor" | "ceil" | "round") => MathFloor,
        ("math", _) => MathOther,
        ("string", "len") => StringLen,
        ("string", "match") => StringMatch,
        ("string", "find") => StringFind,
        ("string", "format") => StringFormat,
        ("string", "byte") => StringByte,
        ("string", "sub") => StringSub,
        ("string", _) => StringOther,
        ("table", "insert") => TableInsert,
        ("table", "find") => TableFind,
        ("table", "concat") => TableConcat,
        ("table", "clone") => TableClone,
        ("table", "freeze") => TableFreeze,
        ("table", "remove") => TableRemove,
        ("table", "sort") => TableSort,
        ("table", "unpack") => TableUnpack,
        ("table", "create") => TableCreate,
        ("task", "spawn" | "defer" | "delay") => Spawn,
        ("task", "wait") => Wait,
        ("coroutine", "wrap" | "create") => Spawn,
        ("os", "clock" | "time") => Clock,
        ("DateTime", "now") => Clock,
        ("Instance", "new" | "fromExisting") => InstanceNew,
        (
            "Vector3"
            | "Vector2"
            | "CFrame"
            | "Color3"
            | "UDim2"
            | "UDim"
            | "BrickColor"
            | "TweenInfo"
            | "NumberRange"
            | "Ray"
            | "Region3"
            | "Rect"
            | "NumberSequence"
            | "ColorSequence"
            | "PhysicalProperties"
            | "Random"
            | "OverlapParams"
            | "RaycastParams"
            | "Axes"
            | "Faces"
            | "NumberSequenceKeypoint"
            | "ColorSequenceKeypoint"
            | "Font"
            | "vector",
            _,
        ) => Constructor,
        _ => Derive,
    }
}

fn global_builtin(name: &str) -> Option<Builtin> {
    use Builtin::*;
    Some(match name {
        "typeof" => Typeof,
        "type" => Type,
        "tonumber" => Tonumber,
        "tostring" => Tostring,
        "assert" => Assert,
        "error" => Error,
        "pcall" => Pcall,
        "xpcall" => Xpcall,
        "select" => Select,
        "require" => Require,
        "loadstring" | "load" => Loadstring,
        "getfenv" => Getfenv,
        "setfenv" => Setfenv,
        "pairs" => Pairs,
        "ipairs" => Ipairs,
        "next" => Next,
        "unpack" => Unpack,
        "rawget" => Rawget,
        "rawset" => Rawset,
        "rawequal" => Rawequal,
        "setmetatable" => Setmetatable,
        "getmetatable" => Getmetatable,
        "print" | "warn" => Print,
        "spawn" | "delay" => Spawn,
        "wait" => Wait,
        "tick" | "time" | "elapsedTime" => Clock,
        _ => return None,
    })
}

fn is_service_name(name: &str) -> bool {
    name.chars().next().is_some_and(|c| c.is_ascii_uppercase())
        && (name.ends_with("Service")
            || matches!(
                name,
                "Workspace"
                    | "Players"
                    | "Lighting"
                    | "ReplicatedFirst"
                    | "ReplicatedStorage"
                    | "ServerStorage"
                    | "StarterGui"
                    | "StarterPack"
                    | "StarterPlayer"
                    | "Teams"
                    | "Chat"
                    | "Debris"
            ))
}

pub(crate) fn number_literal(text: &str) -> Option<f64> {
    let cleaned: String = text.chars().filter(|c| *c != '_').collect();
    if let Some(hex) = cleaned
        .strip_prefix("0x")
        .or_else(|| cleaned.strip_prefix("0X"))
    {
        return i64::from_str_radix(hex, 16).ok().map(|v| v as f64);
    }
    if let Some(bin) = cleaned
        .strip_prefix("0b")
        .or_else(|| cleaned.strip_prefix("0B"))
    {
        return i64::from_str_radix(bin, 2).ok().map(|v| v as f64);
    }
    cleaned.parse().ok()
}

pub(crate) fn string_literal(token: &TokenReference) -> Option<Rc<str>> {
    match token.token().token_type() {
        TokenType::StringLiteral { literal, .. } => Some(Rc::from(literal.as_str())),
        _ => None,
    }
}

pub(crate) fn symbol_of(token: &TokenReference) -> Option<Symbol> {
    match token.token().token_type() {
        TokenType::Symbol { symbol } => Some(*symbol),
        _ => None,
    }
}

/// Strips parentheses and type assertions.
pub(crate) fn unwrap_expr(mut expr: &Expression) -> &Expression {
    loop {
        match expr {
            Expression::Parentheses { expression, .. } => expr = expression,
            Expression::TypeAssertion { expression, .. } => expr = expression,
            _ => return expr,
        }
    }
}

pub(crate) fn is_falsy_literal(expr: &Expression) -> bool {
    match unwrap_expr(expr) {
        Expression::Symbol(token) => matches!(symbol_of(token), Some(Symbol::False | Symbol::Nil)),
        _ => false,
    }
}

/// Most fields of a table iterated one by one (see `exec_unrolled`).
const MAX_UNROLLED_FIELDS: usize = 16;
/// Loops nested deeper than this are not run once per field (the cost grows
/// as fields^depth); they use the merged element instead.
const MAX_UNROLL_NESTING: u32 = 2;

/// Does the loop body copy entries by key (`copy[key] = value`,
/// `totals[key] += value`), without creating functions? Only such loops are
/// run once per field: closures created in the body capture the loop
/// variables, which a per-field run would leave bound to the last field.
fn copies_by_key(block: &Block, key: &str) -> bool {
    struct Scan<'k> {
        key: &'k str,
        copies: bool,
        functions: bool,
    }
    impl Scan<'_> {
        fn target(&mut self, var: &Var) {
            if let Var::Expression(var) = var {
                if let Some(Suffix::Index(Index::Brackets { expression, .. })) =
                    var.suffixes().last()
                {
                    if matches!(unwrap_expr(expression), Expression::Var(Var::Name(t)) if token_name(t) == self.key)
                    {
                        self.copies = true;
                    }
                }
            }
        }
    }
    impl full_moon::visitors::Visitor for Scan<'_> {
        fn visit_function_body(&mut self, _: &full_moon::ast::FunctionBody) {
            self.functions = true;
        }
        fn visit_assignment(&mut self, assignment: &full_moon::ast::Assignment) {
            for var in assignment.variables() {
                self.target(var);
            }
        }
        fn visit_compound_assignment(&mut self, assignment: &full_moon::ast::CompoundAssignment) {
            self.target(assignment.lhs());
        }
    }
    let mut scan = Scan {
        key,
        copies: false,
        functions: false,
    };
    full_moon::visitors::Visit::visit(block, &mut scan);
    scan.copies && !scan.functions
}

/// The fields of the iterated collection, when every key is known: a server
/// table with named fields only (not an array, not filled with dynamic keys,
/// not sent by the client). `ipairs` only visits array entries: not unrolled.
fn known_fields<'a>(
    collection: &Value<'a>,
    exprs: &[&'a Expression],
) -> Option<Vec<(Rc<str>, Value<'a>)>> {
    let Kind::Table(table) = &collection.kind else {
        return None;
    };
    let ipairs = exprs.first().is_some_and(|e| {
        matches!(unwrap_expr(e), Expression::FunctionCall(call)
            if matches!(call.prefix(), Prefix::Name(t) if token_name(t) == "ipairs"))
    });
    if ipairs
        || collection.is_tainted()
        || table.dynamic.is_some()
        || table.fields.is_empty()
        || table.fields.len() > MAX_UNROLLED_FIELDS
    {
        return None;
    }
    Some(
        table
            .fields
            .iter()
            .map(|(k, v)| (k.clone(), v.clone()))
            .collect(),
    )
}

/// An expression whose value is the outcome of a check.
pub(crate) fn is_condition(expr: &Expression) -> bool {
    match unwrap_expr(expr) {
        Expression::BinaryOperator { binop, .. } => matches!(
            binop,
            BinOp::And(_)
                | BinOp::Or(_)
                | BinOp::TwoEqual(_)
                | BinOp::TildeEqual(_)
                | BinOp::LessThan(_)
                | BinOp::LessThanEqual(_)
                | BinOp::GreaterThan(_)
                | BinOp::GreaterThanEqual(_)
        ),
        Expression::UnaryOperator {
            unop: UnOp::Not(_), ..
        } => true,
        Expression::FunctionCall(_) => true,
        _ => false,
    }
}

/// An expression measuring a value (`#x`, `(a - b).Magnitude`,
/// `player:DistanceFromCharacter(p)`, `math.abs(x)`, `string.len(s)`), or an
/// offset whose magnitude is measured later (`a - b`).
pub(crate) fn is_measure(expr: &Expression) -> bool {
    match unwrap_expr(expr) {
        Expression::BinaryOperator {
            binop: BinOp::Minus(_),
            ..
        } => true,
        Expression::UnaryOperator {
            unop: UnOp::Hash(_),
            ..
        } => true,
        Expression::Var(Var::Expression(var)) => matches!(
            var.suffixes().last(),
            Some(Suffix::Index(Index::Dot { name, .. })) if token_name(name) == "Magnitude"
        ),
        Expression::FunctionCall(call) => {
            let text = compact(call);
            text.contains("DistanceFromCharacter")
                || text.starts_with("math.abs(")
                || text.starts_with("string.len(")
        }
        _ => false,
    }
}

/// Arguments of a call, as expressions.
pub(crate) fn args_exprs(args: &FunctionArgs) -> Vec<&Expression> {
    match args {
        FunctionArgs::Parentheses { arguments, .. } => arguments.iter().collect(),
        _ => Vec::new(),
    }
}

impl<'a> Analyzer<'a> {
    // ------------------------------------------------------------------
    // Blocks and statements
    // ------------------------------------------------------------------

    pub(crate) fn exec_block(
        &mut self,
        frame: &mut Frame<'a>,
        block: &'a Block,
        mut state: State<'a>,
    ) -> State<'a> {
        frame.scopes.push(BTreeMap::new());
        for stmt in block.stmts() {
            if state.dead {
                break;
            }
            // Out of budget, nested calls stop, but the handler's own body
            // (and module code) still runs: its sinks are cheap to check.
            if self.budget == 0 && (self.stack.len() > 1 || self.summary_nesting > 0) {
                break;
            }
            self.budget = self.budget.saturating_sub(1);
            state = self.exec_stmt(frame, stmt, state);
        }
        if !state.dead {
            if let Some(last) = block.last_stmt() {
                state = self.exec_last(frame, last, state);
            }
        }
        frame.scopes.pop();
        state
    }

    fn exec_last(
        &mut self,
        frame: &mut Frame<'a>,
        last: &'a LastStmt,
        mut state: State<'a>,
    ) -> State<'a> {
        match last {
            LastStmt::Return(ret) => {
                let exprs: Vec<&'a Expression> = ret.returns().iter().collect();
                let loc = self.loc(frame.file, ret);
                let mut values = self.eval_list(frame, &mut state, &exprs);
                if frame.summary.is_some() {
                    self.record_summary_return(frame, &mut state, exprs.first().copied());
                }
                let name = frame.name.clone();
                if frame.closure.is_some() {
                    values = values
                        .into_iter()
                        .map(|v| v.step(loc, &format!("returned from `{name}`")))
                        .collect();
                }
                frame.add_return(values);
                frame.return_states.push(state);
                State::dead()
            }
            LastStmt::Break(_) => {
                if let Some(ctx) = frame.loops.last_mut() {
                    ctx.breaks.push(state);
                }
                State::dead()
            }
            LastStmt::Continue(_) => {
                if let Some(ctx) = frame.loops.last_mut() {
                    ctx.continues.push(state);
                }
                State::dead()
            }
            _ => state,
        }
    }

    fn exec_stmt(
        &mut self,
        frame: &mut Frame<'a>,
        stmt: &'a Stmt,
        mut state: State<'a>,
    ) -> State<'a> {
        match stmt {
            Stmt::LocalAssignment(local) => {
                let exprs: Vec<&'a Expression> = local.expressions().iter().collect();
                let mut values = self.eval_list(frame, &mut state, &exprs);
                // `local ok = isValid(x)`: remember the condition behind `ok`.
                if let (Some(first), Some(expr)) = (values.first_mut(), exprs.first()) {
                    if is_condition(expr) || is_measure(expr) {
                        first.defined_by = Some(expr);
                    }
                    // `local current = state[player]`: testing `current` tests
                    // that state (luau-shield007).
                    if let Expression::Var(var @ Var::Expression(_)) = unwrap_expr(expr) {
                        first.alias = self.state_key(frame, var).map(|k| Rc::from(k.as_str()));
                    }
                }
                for (i, name) in local.names().iter().enumerate() {
                    let value = values.get(i).cloned().unwrap_or_else(Value::nil);
                    self.declare_local(frame, &mut state, name, value);
                }
            }
            Stmt::ConstAssignment(local) => {
                let exprs: Vec<&'a Expression> = local.expressions().iter().collect();
                let values = self.eval_list(frame, &mut state, &exprs);
                for (i, name) in local.names().iter().enumerate() {
                    let value = values.get(i).cloned().unwrap_or_else(Value::nil);
                    self.declare_local(frame, &mut state, name, value);
                }
            }
            Stmt::Assignment(assignment) => {
                let exprs: Vec<&'a Expression> = assignment.expressions().iter().collect();
                let values = self.eval_list(frame, &mut state, &exprs);
                for (i, var) in assignment.variables().iter().enumerate() {
                    let value = values.get(i).cloned().unwrap_or_else(Value::nil);
                    self.assign(frame, &mut state, var, value, None);
                }
            }
            Stmt::CompoundAssignment(compound) => {
                let current = self.eval_var(frame, &mut state, compound.lhs());
                let rhs = self.eval(frame, &mut state, compound.rhs());
                let op = compound.compound_operator().token().token().to_string();
                let combined = if op.starts_with("..") {
                    self.concat(&current, &rhs)
                } else {
                    let mut v = self.arith(&current, &rhs);
                    v.path = None;
                    v
                };
                self.assign(frame, &mut state, compound.lhs(), combined, Some((op, rhs)));
            }
            Stmt::FunctionCall(call) => {
                let _ = self.eval_suffixed(
                    frame,
                    &mut state,
                    call.prefix(),
                    call.suffixes().collect(),
                    true,
                );
            }
            Stmt::FunctionDeclaration(decl) => {
                let names: Vec<String> = decl.name().names().iter().map(token_name).collect();
                let method = decl.name().method_name().map(token_name);
                let mut full: Vec<String> = names.clone();
                if let Some(m) = &method {
                    full.push(m.clone());
                }
                let display = match &method {
                    Some(m) => format!("{}:{m}", names.join(".")),
                    None => names.join("."),
                };
                let closure =
                    self.make_closure(frame, decl.body(), &display, method.is_some(), decl);
                let value = Value::of(Kind::Func(Rc::new(vec![Func::Closure(closure.clone())])));
                // Custom sources (Knit services and configured patterns).
                if let Some(source) = self
                    .config
                    .sources
                    .iter()
                    .find(|s| s.pattern.matches(&full))
                {
                    let loc = self.loc(frame.file, decl.name());
                    let top_level = frame.closure.is_none();
                    self.register_entry(
                        vec![Func::Closure(closure.clone())],
                        EntryKind::Custom {
                            trusted: source.trusted_parameters,
                            name: display.clone(),
                            self_path: method.as_ref().map(|_| {
                                let root = frame
                                    .lookup(&names[0])
                                    .unwrap_or_else(|| global_id(frame.file, &names[0]));
                                let keys =
                                    names[1..].iter().map(|s| Rc::from(s.as_str())).collect();
                                (root, keys)
                            }),
                        },
                        loc,
                        &state,
                        false,
                        top_level,
                    );
                }
                let last = full.last().map(String::as_str).unwrap_or("");
                let top_level = frame.closure.is_none();
                let loc = self.loc(frame.file, decl.name());
                if last == "OnServerInvoke" && full.len() > 1 {
                    // `function Remote.OnServerInvoke(player, ...)`
                    self.register_entry(
                        vec![Func::Closure(closure.clone())],
                        EntryKind::Remote {
                            event: "OnServerInvoke",
                            remote: full[..full.len() - 1].join("."),
                        },
                        loc,
                        &state,
                        false,
                        top_level,
                    );
                } else if matches!(
                    last,
                    "KnitStart" | "KnitInit" | "Start" | "Init" | "OnStart" | "OnInit"
                ) {
                    // Lifecycle methods called by frameworks: they often connect remotes.
                    self.register_entry(
                        vec![Func::Closure(closure.clone())],
                        EntryKind::Callback {
                            player_param: false,
                        },
                        loc,
                        &state,
                        false,
                        top_level,
                    );
                }
                if full.len() == 1 {
                    self.write_name(frame, &mut state, &full[0], value);
                } else {
                    let root = &full[0];
                    let keys: Vec<Rc<str>> =
                        full[1..].iter().map(|s| Rc::from(s.as_str())).collect();
                    if let Some(id) = frame.lookup(root) {
                        self.store_path(frame, &mut state, id, &keys, value);
                    } else {
                        let id = global_id(frame.file, root);
                        self.store_path(frame, &mut state, id, &keys, value);
                    }
                }
            }
            Stmt::LocalFunction(local) => {
                let name = token_name(local.name());
                let id = var_id(frame.file, local.name());
                frame.declare(&name, id);
                let closure = self.make_closure(frame, local.body(), &name, false, local.name());
                state.vars.insert(
                    id,
                    Value::of(Kind::Func(Rc::new(vec![Func::Closure(closure)]))),
                );
            }
            Stmt::ConstFunction(local) => {
                let name = token_name(local.name());
                let id = var_id(frame.file, local.name());
                frame.declare(&name, id);
                let closure = self.make_closure(frame, local.body(), &name, false, local.name());
                state.vars.insert(
                    id,
                    Value::of(Kind::Func(Rc::new(vec![Func::Closure(closure)]))),
                );
            }
            Stmt::Do(block) => {
                state = self.exec_block(frame, block.block(), state);
            }
            Stmt::If(stmt) => {
                let mut condition_state = state;
                let cond_value = self.eval(frame, &mut condition_state, stmt.condition());
                self.pending_lock_reads.clear();
                let refinement =
                    self.refine_condition(frame, &mut condition_state, stmt.condition());
                let lock_reads = std::mem::take(&mut self.pending_lock_reads);
                let mut then_state = condition_state.clone();
                self.apply_facts(&mut then_state, &refinement.on_true);
                if let Some(binding) = stmt.binding() {
                    frame.scopes.push(BTreeMap::new());
                    self.declare_local(frame, &mut then_state, binding.name(), cond_value.clone());
                }
                // luau-shield007 bookkeeping: which branches do expensive work,
                // which states each branch changes.
                let consumed_before: Vec<Rc<str>> =
                    condition_state.consumed.keys().cloned().collect();
                let work_start = self.expensive_count();
                let mut branch_work = Vec::new();
                self.enter_branch(frame);
                let then_end = self.exec_block(frame, stmt.block(), then_state);
                self.leave_branch();
                branch_work.push(self.expensive_count() > work_start);
                if stmt.binding().is_some() {
                    frame.scopes.pop();
                }
                // luau-shield007 lock pattern: `if busy[player] then return end`
                // (or the work guarded by `if not busy[player] then ... end`).
                let negated = matches!(
                    unwrap_expr(stmt.condition()),
                    Expression::UnaryOperator {
                        unop: UnOp::Not(_),
                        ..
                    }
                );
                if then_end.dead || negated {
                    if let Some(entry) = self.entry.as_mut() {
                        entry.lock_reads.extend(lock_reads);
                    }
                }
                let mut ends = vec![then_end];
                let mut else_state = condition_state;
                self.apply_facts(&mut else_state, &refinement.on_false);
                if let Some(else_ifs) = stmt.else_if() {
                    for else_if in else_ifs {
                        if else_state.dead {
                            break;
                        }
                        let _ = self.eval(frame, &mut else_state, else_if.condition());
                        let r = self.refine_condition(frame, &mut else_state, else_if.condition());
                        let mut branch = else_state.clone();
                        self.apply_facts(&mut branch, &r.on_true);
                        let before = self.expensive_count();
                        self.enter_branch(frame);
                        ends.push(self.exec_block(frame, else_if.block(), branch));
                        self.leave_branch();
                        branch_work.push(self.expensive_count() > before);
                        self.apply_facts(&mut else_state, &r.on_false);
                    }
                }
                let else_end = match stmt.else_block() {
                    Some(block) if !else_state.dead => {
                        let before = self.expensive_count();
                        self.enter_branch(frame);
                        let end = self.exec_block(frame, block, else_state);
                        self.leave_branch();
                        branch_work.push(self.expensive_count() > before);
                        end
                    }
                    _ => {
                        // Without `else`, the other path does nothing.
                        if !else_state.dead {
                            branch_work.push(false);
                        }
                        else_state
                    }
                };
                ends.push(else_end);
                if let Some(entry) = self.entry.as_mut() {
                    // Work done whichever branch runs is not conditional.
                    if branch_work.iter().all(|w| *w) {
                        entry
                            .unconditional
                            .extend(work_start..entry.expensive.len());
                    }
                    // A state changed on two sides of the same test is a
                    // toggle: each request flips it and does the work.
                    let mut changed: BTreeMap<Rc<str>, usize> = BTreeMap::new();
                    for end in ends.iter().filter(|e| !e.dead) {
                        for text in end.consumed.keys() {
                            if !consumed_before.contains(text) {
                                *changed.entry(text.clone()).or_insert(0) += 1;
                            }
                        }
                    }
                    for (text, count) in changed {
                        if count >= 2 {
                            entry.toggles.insert(text);
                        }
                    }
                }
                state = State::join_all(ends);
            }
            Stmt::While(stmt) => {
                let _ = self.eval(frame, &mut state, stmt.condition());
                state = self.exec_loop(
                    frame,
                    state,
                    Some(stmt.condition()),
                    stmt.block(),
                    |_, _, _| {},
                );
            }
            Stmt::Repeat(stmt) => {
                // The body runs at least once.
                frame.loops.push(LoopCtx {
                    breaks: Vec::new(),
                    continues: Vec::new(),
                });
                let mut entry = state;
                let mut exit = State::dead();
                for _ in 0..2 {
                    let body_end = self.exec_block(frame, stmt.block(), entry.clone());
                    let ctx = frame.loops.last_mut().expect("loop context");
                    let continues = std::mem::take(&mut ctx.continues);
                    let mut end = State::join_all(std::iter::once(body_end).chain(continues));
                    if end.dead {
                        break;
                    }
                    let _ = self.eval(frame, &mut end, stmt.until());
                    let r = self.refine_condition(frame, &mut end, stmt.until());
                    let mut leave = end.clone();
                    self.apply_facts(&mut leave, &r.on_true);
                    exit = exit.join(leave);
                    let mut again = end;
                    self.apply_facts(&mut again, &r.on_false);
                    entry = entry.join(again);
                }
                let ctx = frame.loops.pop().expect("loop context");
                state = State::join_all(std::iter::once(exit).chain(ctx.breaks));
            }
            Stmt::NumericFor(stmt) => {
                let start = self.eval(frame, &mut state, stmt.start());
                let end = self.eval(frame, &mut state, stmt.end());
                let step = stmt.step().map(|s| self.eval(frame, &mut state, s));
                let mut index = Value::of(Kind::Number(None));
                index.add_flows(start.derived().flows);
                index.add_flows(end.derived().flows);
                if let Some(step) = step {
                    index.add_flows(step.derived().flows);
                }
                let token = stmt.index_variable();
                state = self.exec_loop(frame, state, None, stmt.block(), |this, frame, state| {
                    this.declare_local(frame, state, token, index.clone());
                });
            }
            Stmt::GenericFor(stmt) => {
                let exprs: Vec<&'a Expression> = stmt.expressions().iter().collect();
                let collection = self.iteration_collection(frame, &mut state, &exprs);
                let names: Vec<&'a TokenReference> = stmt.names().iter().collect();
                let copies = names
                    .first()
                    .is_some_and(|key| copies_by_key(stmt.block(), &token_name(key)));
                let fields = known_fields(&collection, &exprs)
                    .filter(|_| copies && self.unroll_depth < MAX_UNROLL_NESTING);
                if let Some(fields) = fields {
                    self.unroll_depth += 1;
                    state = self.exec_unrolled(frame, state, stmt.block(), &names, fields);
                    self.unroll_depth -= 1;
                } else {
                    let (key, element) = self.iteration_values(&collection);
                    state =
                        self.exec_loop(frame, state, None, stmt.block(), |this, frame, state| {
                            for (i, name) in names.iter().enumerate() {
                                let value = match i {
                                    0 => key.clone(),
                                    1 => element.clone(),
                                    _ => Value::unknown(),
                                };
                                this.declare_local(frame, state, name, value);
                            }
                        });
                }
            }
            _ => {}
        }
        state
    }

    /// Runs a loop body a bounded number of times and merges the results.
    fn exec_loop(
        &mut self,
        frame: &mut Frame<'a>,
        state: State<'a>,
        condition: Option<&'a Expression>,
        block: &'a Block,
        mut bind: impl FnMut(&mut Self, &mut Frame<'a>, &mut State<'a>),
    ) -> State<'a> {
        frame.loops.push(LoopCtx {
            breaks: Vec::new(),
            continues: Vec::new(),
        });
        let mut head = state;
        let mut exit = State::dead();
        for _ in 0..2 {
            let mut cond_state = head.clone();
            let mut body_state = cond_state.clone();
            if let Some(condition) = condition {
                let r = self.refine_condition(frame, &mut cond_state, condition);
                body_state = cond_state.clone();
                self.apply_facts(&mut body_state, &r.on_true);
                let mut leave = cond_state;
                self.apply_facts(&mut leave, &r.on_false);
                exit = exit.join(leave);
            } else {
                exit = exit.join(cond_state);
            }
            frame.scopes.push(BTreeMap::new());
            bind(self, frame, &mut body_state);
            let body_end = self.exec_block(frame, block, body_state);
            frame.scopes.pop();
            let ctx = frame.loops.last_mut().expect("loop context");
            let continues = std::mem::take(&mut ctx.continues);
            let end = State::join_all(std::iter::once(body_end).chain(continues));
            if end.dead {
                break;
            }
            if let Some(condition) = condition {
                let mut again = end.clone();
                let _ = self.eval(frame, &mut again, condition);
            }
            head = head.join(end);
        }
        let ctx = frame.loops.pop().expect("loop context");
        State::join_all(std::iter::once(exit).chain(ctx.breaks))
    }

    /// The collection iterated by `for k, v in <exprs>`.
    fn iteration_collection(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        exprs: &[&'a Expression],
    ) -> Value<'a> {
        let values = self.eval_list(frame, state, exprs);
        let first = values.first().cloned().unwrap_or_default();
        // `pairs(t)` / `ipairs(t)` evaluate to the table itself (see builtins);
        // generalized iteration uses the table directly.
        match &first.kind {
            Kind::Func(funcs)
                if funcs
                    .iter()
                    .any(|f| matches!(f, Func::Builtin(Builtin::Next))) =>
            {
                values.get(1).cloned().unwrap_or_default()
            }
            _ => first,
        }
    }

    /// `for k, v in t` over a table whose keys are all known (a table built
    /// by the server, such as `{ coins = amount }`): the body runs once per
    /// field, with the field's own key and value, so that writing
    /// `copy[k] = v` keeps each field apart.
    fn exec_unrolled(
        &mut self,
        frame: &mut Frame<'a>,
        state: State<'a>,
        block: &'a Block,
        names: &[&'a TokenReference],
        fields: Vec<(Rc<str>, Value<'a>)>,
    ) -> State<'a> {
        frame.loops.push(LoopCtx {
            breaks: Vec::new(),
            continues: Vec::new(),
        });
        let mut current = state;
        for (key, value) in fields {
            if current.dead {
                break;
            }
            // A field whose value is nil at run time is not visited: every
            // iteration may be skipped.
            let skipped = current.clone();
            let key = match key.parse::<f64>() {
                Ok(n) => Value::of(Kind::Number(Some(n))),
                Err(_) => Value::of(Kind::Str(Some(key))),
            };
            frame.scopes.push(BTreeMap::new());
            for (i, name) in names.iter().enumerate() {
                let bound = match i {
                    0 => key.clone(),
                    1 => value.clone(),
                    _ => Value::unknown(),
                };
                self.declare_local(frame, &mut current, name, bound);
            }
            let body_end = self.exec_block(frame, block, current);
            frame.scopes.pop();
            let ctx = frame.loops.last_mut().expect("loop context");
            let continues = std::mem::take(&mut ctx.continues);
            current = State::join_all([skipped, body_end].into_iter().chain(continues));
        }
        let ctx = frame.loops.pop().expect("loop context");
        State::join_all(std::iter::once(current).chain(ctx.breaks))
    }

    /// Key and element values for `for k, v in <collection>`.
    fn iteration_values(&self, collection: &Value<'a>) -> (Value<'a>, Value<'a>) {
        let element = self.element_of(collection);
        let key = if collection.is_tainted() {
            let mut key = Value::unknown();
            key.add_flows(collection.flows.iter().map(|f| Flow {
                checks: f.checks & check::INHERITED_BY_FIELDS,
                ..f.clone()
            }));
            key
        } else {
            Value::unknown()
        };
        (key, element)
    }

    /// The value of an element of a collection.
    pub(crate) fn element_of(&self, collection: &Value<'a>) -> Value<'a> {
        let mut element = match &collection.kind {
            Kind::Table(table) => {
                let mut acc: Option<Value<'a>> = None;
                for value in table.fields.values().chain(table.dynamic.as_deref()) {
                    acc = Some(match acc {
                        None => value.clone(),
                        Some(a) => a.join(value),
                    });
                }
                acc.unwrap_or_default()
            }
            _ => Value::unknown(),
        };
        element.add_flows(collection.flows.iter().map(|f| Flow {
            checks: f.checks & check::INHERITED_BY_FIELDS,
            raw: f.raw,
            ..f.clone()
        }));
        element.player_rel = collection.player_rel;
        element
    }

    pub(crate) fn declare_local(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        token: &'a TokenReference,
        value: Value<'a>,
    ) {
        let name = token_name(token);
        let id = var_id(frame.file, token);
        let loc = self.loc(frame.file, token);
        let value = self
            .named(value, &name)
            .step(loc, &format!("assigned to `{name}`"));
        frame.declare(&name, id);
        state.invalidate_paths(id, None);
        state.vars.insert(id, value);
    }

    /// Gives a name to anonymous closures and a display path to path-less values.
    fn named(&self, mut value: Value<'a>, name: &str) -> Value<'a> {
        if let Kind::Func(funcs) = &value.kind {
            if funcs.len() == 1 {
                if let Func::Closure(c) = &funcs[0] {
                    if &*c.name == "<anonymous>" {
                        let renamed = Closure {
                            file: c.file,
                            body: c.body,
                            name: Rc::from(name),
                            loc: c.loc,
                            is_method: c.is_method,
                            captured: c.captured.clone(),
                        };
                        value.kind = Kind::Func(Rc::new(vec![Func::Closure(Rc::new(renamed))]));
                    }
                }
            }
        }
        if value.path.is_none() {
            value.path = Some(Rc::from(name));
        }
        value
    }

    fn write_name(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        name: &str,
        value: Value<'a>,
    ) {
        let value = self.named(value, name);
        let id = frame
            .lookup(name)
            .unwrap_or_else(|| global_id(frame.file, name));
        state.invalidate_paths(id, None);
        state.vars.insert(id, value);
    }

    pub(crate) fn make_closure(
        &mut self,
        frame: &Frame<'a>,
        body: &'a FunctionBody,
        name: &str,
        is_method: bool,
        at: &impl Node,
    ) -> Rc<Closure<'a>> {
        Rc::new(Closure {
            file: frame.file,
            body,
            name: Rc::from(name),
            loc: self.loc(frame.file, at),
            is_method,
            captured: frame.capture(),
        })
    }

    // ------------------------------------------------------------------
    // Assignment
    // ------------------------------------------------------------------

    /// Assigns `value` to `var`. `compound` carries the operator and the
    /// right-hand side of `x += y` for messages.
    fn assign(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        var: &'a Var,
        value: Value<'a>,
        compound: Option<(String, Value<'a>)>,
    ) {
        let loc = self.loc(frame.file, var);
        match var {
            Var::Name(token) => {
                let name = token_name(token);
                // luau-shield007 lock pattern: `debounce = true`. A local of
                // this function is only a copy of the state: changing it
                // changes nothing for the next request.
                let local = frame
                    .scopes
                    .iter()
                    .any(|scope| scope.contains_key(name.as_str()));
                if let (false, Some(key)) = (local, self.state_key(frame, var)) {
                    self.consume_expect(state, &key, &value, false, false);
                }
                self.note_lock_write(&name, &value, false);
                let value = value.step(loc, &format!("assigned to `{name}`"));
                self.write_name(frame, state, &name, value);
            }
            Var::Expression(var_expr) => {
                let suffixes: Vec<&'a Suffix> = var_expr.suffixes().collect();
                let Some((last, init)) = suffixes.split_last() else {
                    return;
                };
                let Suffix::Index(index) = last else {
                    return;
                };
                let base = self
                    .eval_suffixed(frame, state, var_expr.prefix(), init.to_vec(), false)
                    .into_iter()
                    .next()
                    .unwrap_or_default();
                let key = match index {
                    Index::Dot { name, .. } => Key::Name(Rc::from(token_name(name).as_str())),
                    Index::Brackets { expression, .. } => {
                        let key_value = self.eval(frame, state, expression);
                        match key_value.str_const() {
                            Some(s) if !key_value.is_tainted() => Key::Name(Rc::from(s)),
                            _ => {
                                let target = self.target_of(frame, expression);
                                Key::Dynamic(key_value, target)
                            }
                        }
                    }
                    _ => return,
                };
                let target_display = compact(var);
                let base_display = {
                    let mut s = compact(var_expr.prefix());
                    for suffix in init {
                        s.push_str(&compact(*suffix));
                    }
                    s
                };
                let shown_value = compound.as_ref().map(|(_, rhs)| rhs).unwrap_or(&value);
                let verb = match &compound {
                    Some((op, _)) if op.starts_with('+') => "added to",
                    Some((op, _)) if op.starts_with('-') => "subtracted from",
                    Some((op, _)) if op.starts_with("..") => "appended to",
                    Some(_) => "combined into",
                    None => "assigned to",
                };
                self.check_assignment_sinks(
                    frame,
                    state,
                    &base,
                    &key,
                    shown_value,
                    &value,
                    loc,
                    &target_display,
                    verb,
                );
                if let Key::Name(name) = &key {
                    if &**name == "OnServerInvoke" {
                        let funcs = value.funcs();
                        let top_level = frame.closure.is_none();
                        self.register_entry(
                            funcs,
                            EntryKind::Remote {
                                event: "OnServerInvoke",
                                remote: base_display.clone(),
                            },
                            loc,
                            state,
                            false,
                            top_level,
                        );
                    }
                }
                // luau-shield007 lock pattern: `busy[player] = true`, `tool.Enabled = false`.
                let per_player = matches!(&key, Key::Dynamic(k, _) if k.player_rel);
                // State machines: `state[player] = "Menu"`, `data[player].Slots[slot] = nil`.
                let mut player_state = per_player;
                let mut client_key = matches!(&key, Key::Dynamic(k, _) if k.is_tainted());
                for suffix in init {
                    if let Suffix::Index(Index::Brackets { expression, .. }) = suffix {
                        let k = self.peek(frame, state, expression);
                        player_state |= k.player_rel && !k.is_tainted();
                        client_key |= !k.deep_flows().is_empty();
                    }
                }
                if let Some(state_key) = self.state_key(frame, var) {
                    self.consume_expect(state, &state_key, &value, player_state, client_key);
                }
                self.note_lock_write(&target_display, &value, per_player);
                // Store into a table we track.
                if let Some((root, keys)) = self.static_path(frame, var_expr.prefix(), init) {
                    let mut keys = keys;
                    let stored =
                        self.escape(value.step(loc, &format!("stored in `{target_display}`")));
                    match key {
                        Key::Name(name) => {
                            keys.push(name);
                            self.store_path(frame, state, root, &keys, stored);
                        }
                        Key::Dynamic(key_value, _) => {
                            self.store_dynamic(state, root, &keys, key_value, stored);
                        }
                    }
                }
            }
            _ => {}
        }
    }

    /// Records an assignment that can set a lock (luau-shield007).
    pub(crate) fn note_lock_write(&mut self, target: &str, value: &Value<'a>, per_player: bool) {
        if self.peek > 0 || matches!(value.kind, Kind::Nil) {
            return;
        }
        if let Some(entry) = self.entry.as_mut() {
            entry.lock_writes.insert(target.to_string());
            if per_player {
                entry.per_player_writes.insert(target.to_string());
            }
        }
    }

    /// A table stored somewhere else is no longer a fresh local table.
    fn escape(&self, mut value: Value<'a>) -> Value<'a> {
        if let Kind::Table(table) = &value.kind {
            if table.fresh_frame.is_some() {
                let mut t = (**table).clone();
                t.fresh_frame = None;
                value.kind = Kind::Table(Rc::new(t));
            }
        }
        value
    }

    /// `root.k1.k2` as (variable id, keys) when the expression is a static path.
    pub(crate) fn static_path(
        &self,
        frame: &Frame<'a>,
        prefix: &'a Prefix,
        suffixes: &[&'a Suffix],
    ) -> Option<(u64, Vec<Rc<str>>)> {
        let Prefix::Name(token) = prefix else {
            return None;
        };
        let name = token_name(token);
        let root = frame
            .lookup(&name)
            .unwrap_or_else(|| global_id(frame.file, &name));
        let mut keys = Vec::new();
        for suffix in suffixes {
            match suffix {
                Suffix::Index(Index::Dot { name, .. }) => {
                    keys.push(Rc::from(token_name(name).as_str()))
                }
                Suffix::Index(Index::Brackets { expression, .. }) => {
                    match unwrap_expr(expression) {
                        Expression::String(token) => keys.push(string_literal(token)?),
                        _ => return None,
                    }
                }
                _ => return None,
            }
        }
        Some((root, keys))
    }

    fn root_value(&self, frame: &Frame<'a>, state: &State<'a>, id: u64) -> Option<Value<'a>> {
        state.vars.get(&id).cloned().or_else(|| {
            self.statics
                .get(&frame.file)
                .and_then(|s| s.get(&id))
                .cloned()
        })
    }

    pub(crate) fn store_path(
        &mut self,
        frame: &Frame<'a>,
        state: &mut State<'a>,
        root: u64,
        keys: &[Rc<str>],
        value: Value<'a>,
    ) {
        let path_key: String = keys.join(".");
        state.invalidate_paths(root, Some(&path_key));
        let Some(current) = self.root_value(frame, state, root) else {
            return;
        };
        if let Some(updated) = with_field(&current, keys, value) {
            state.vars.insert(root, updated);
        }
    }

    fn store_dynamic(
        &mut self,
        state: &mut State<'a>,
        root: u64,
        keys: &[Rc<str>],
        key: Value<'a>,
        value: Value<'a>,
    ) {
        let Some(current) = state.vars.get(&root).cloned() else {
            return;
        };
        if let Some(updated) = with_dynamic(&current, keys, key, value) {
            state.vars.insert(root, updated);
        }
    }

    // ------------------------------------------------------------------
    // Expressions
    // ------------------------------------------------------------------

    /// Evaluates a list of expressions, expanding the last one if it can
    /// produce several values.
    pub(crate) fn eval_list(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        exprs: &[&'a Expression],
    ) -> Vec<Value<'a>> {
        let mut out = Vec::new();
        for (i, expr) in exprs.iter().enumerate() {
            if i + 1 == exprs.len() {
                out.extend(self.eval_multi(frame, state, expr));
            } else {
                out.push(self.eval(frame, state, expr));
            }
        }
        out
    }

    pub(crate) fn eval_multi(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        expr: &'a Expression,
    ) -> Vec<Value<'a>> {
        match expr {
            Expression::FunctionCall(call) => self.eval_suffixed(
                frame,
                state,
                call.prefix(),
                call.suffixes().collect(),
                false,
            ),
            Expression::Symbol(token) if symbol_of(token) == Some(Symbol::Ellipsis) => {
                let mut values = frame.varargs.clone();
                if let Some(rest) = &frame.vararg_rest {
                    for _ in 0..4 {
                        values.push(rest.clone());
                    }
                }
                // `...` is not a variable: apply a permission guard here.
                if let Some(guard) = &state.admin {
                    for value in &mut values {
                        value.privilege_deep(guard);
                    }
                }
                values
            }
            Expression::Var(Var::Expression(var_expr)) => {
                let suffixes: Vec<&'a Suffix> = var_expr.suffixes().collect();
                self.eval_suffixed(frame, state, var_expr.prefix(), suffixes, false)
            }
            _ => vec![self.eval(frame, state, expr)],
        }
    }

    pub(crate) fn eval(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        expr: &'a Expression,
    ) -> Value<'a> {
        match expr {
            Expression::Number(token) => {
                Value::of(Kind::Number(number_literal(&token.token().to_string())))
            }
            Expression::String(token) => Value::of(Kind::Str(string_literal(token))),
            Expression::Symbol(token) => match symbol_of(token) {
                Some(Symbol::True) => Value::of(Kind::Bool(Some(true))),
                Some(Symbol::False) => Value::of(Kind::Bool(Some(false))),
                Some(Symbol::Nil) => Value::nil(),
                Some(Symbol::Ellipsis) => {
                    let mut values = frame.varargs.iter();
                    let mut value = match (values.next(), &frame.vararg_rest) {
                        (Some(first), _) => first.clone(),
                        (None, Some(rest)) => rest.clone(),
                        (None, None) => Value::nil(),
                    };
                    if let Some(guard) = &state.admin {
                        value.privilege_deep(guard);
                    }
                    value
                }
                _ => Value::unknown(),
            },
            Expression::Parentheses { expression, .. } => self.eval(frame, state, expression),
            Expression::TypeAssertion { expression, .. } => self.eval(frame, state, expression),
            Expression::UnaryOperator { unop, expression } => {
                let operand = self.eval(frame, state, expression);
                match unop {
                    UnOp::Not(_) => Value::of(Kind::Bool(None)),
                    UnOp::Hash(_) => {
                        let mut v = Value::of(Kind::Number(None));
                        for flow in operand.flows {
                            let mut checks = check::TYPE_NUMBER | check::LOWER | check::NAN_SAFE;
                            if flow.any(check::LENGTH) {
                                checks |= check::UPPER;
                            }
                            checks |= flow.checks & check::KEPT;
                            v.add_flows([Flow {
                                checks,
                                raw: false,
                                instance_data: flow.instance_data,
                                ..flow
                            }]);
                        }
                        v
                    }
                    UnOp::Minus(_) => {
                        let mut v = operand.derived();
                        v.kind = match operand.kind {
                            Kind::Number(Some(n)) => Kind::Number(Some(-n)),
                            _ => Kind::Number(None),
                        };
                        for flow in &mut v.flows {
                            let lower = flow.checks & check::LOWER != 0;
                            let upper = flow.checks & check::UPPER != 0;
                            flow.checks &= !check::BOUNDS;
                            if lower {
                                flow.checks |= check::UPPER;
                            }
                            if upper {
                                flow.checks |= check::LOWER;
                            }
                        }
                        v
                    }
                    _ => operand.derived(),
                }
            }
            Expression::BinaryOperator { lhs, binop, rhs } => {
                self.eval_binop(frame, state, lhs, binop, rhs)
            }
            Expression::Function(function) => {
                let closure = self.make_closure(
                    frame,
                    function.body(),
                    "<anonymous>",
                    false,
                    function.function_token(),
                );
                Value::of(Kind::Func(Rc::new(vec![Func::Closure(closure)])))
            }
            Expression::FunctionCall(call) => self
                .eval_suffixed(
                    frame,
                    state,
                    call.prefix(),
                    call.suffixes().collect(),
                    false,
                )
                .into_iter()
                .next()
                .unwrap_or_else(Value::nil),
            Expression::IfExpression(if_expr) => {
                let _ = self.eval(frame, state, if_expr.condition());
                let r = self.refine_condition(frame, state, if_expr.condition());
                let mut then_state = state.clone();
                self.apply_facts(&mut then_state, &r.on_true);
                let mut result = self.eval(frame, &mut then_state, if_expr.if_expression());
                let mut else_state = state.clone();
                self.apply_facts(&mut else_state, &r.on_false);
                if let Some(else_ifs) = if_expr.else_if_expressions() {
                    for else_if in else_ifs {
                        let _ = self.eval(frame, &mut else_state, else_if.condition());
                        let r2 = self.refine_condition(frame, &mut else_state, else_if.condition());
                        let mut branch = else_state.clone();
                        self.apply_facts(&mut branch, &r2.on_true);
                        let v = self.eval(frame, &mut branch, else_if.expression());
                        result = result.join(&v);
                        self.apply_facts(&mut else_state, &r2.on_false);
                    }
                }
                let v = self.eval(frame, &mut else_state, if_expr.else_expression());
                result.join(&v)
            }
            Expression::InterpolatedString(interpolated) => {
                let mut v = Value::of(Kind::Str(None));
                for part in interpolated.expressions() {
                    let value = self.eval(frame, state, part);
                    v.add_flows(value.derived().flows);
                }
                v
            }
            Expression::TableConstructor(table) => self.eval_table(frame, state, table),
            Expression::Var(var) => self.eval_var(frame, state, var),
            _ => Value::unknown(),
        }
    }

    fn eval_table(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        table: &'a full_moon::ast::TableConstructor,
    ) -> Value<'a> {
        let mut out = Table {
            fresh_frame: Some(frame.id),
            ..Table::default()
        };
        let fields: Vec<&'a Field> = table.fields().iter().collect();
        let count = fields.len();
        for (i, field) in fields.into_iter().enumerate() {
            match field {
                Field::NameKey { key, value, .. } => {
                    let v = self.eval(frame, state, value);
                    out.fields
                        .insert(Rc::from(token_name(key).as_str()), self.escape(v));
                }
                Field::ExpressionKey { key, value, .. } => {
                    let k = self.eval(frame, state, key);
                    let v = self.eval(frame, state, value);
                    let v = self.escape(v);
                    match k.str_const() {
                        Some(name) if !k.is_tainted() => {
                            out.fields.insert(Rc::from(name), v);
                        }
                        _ => {
                            let mut v = v;
                            v.add_flows(k.flows.clone());
                            out.dynamic = Some(Box::new(match out.dynamic.take() {
                                Some(d) => d.join(&v),
                                None => v,
                            }));
                        }
                    }
                }
                Field::NoKey(expr) => {
                    let values = if i + 1 == count {
                        self.eval_multi(frame, state, expr)
                    } else {
                        vec![self.eval(frame, state, expr)]
                    };
                    for v in values {
                        let v = self.escape(v);
                        out.dynamic = Some(Box::new(match out.dynamic.take() {
                            Some(d) => d.join(&v),
                            None => v,
                        }));
                    }
                }
                _ => {}
            }
        }
        Value::of(Kind::Table(Rc::new(out)))
    }

    fn eval_binop(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        lhs: &'a Expression,
        binop: &BinOp,
        rhs: &'a Expression,
    ) -> Value<'a> {
        match binop {
            BinOp::And(_) | BinOp::Or(_) => {
                let left = self.eval(frame, state, lhs);
                let r = self.refine_condition(frame, state, lhs);
                let mut right_state = state.clone();
                let facts = if matches!(binop, BinOp::And(_)) {
                    &r.on_true
                } else {
                    &r.on_false
                };
                self.apply_facts(&mut right_state, facts);
                let right = self.eval(frame, &mut right_state, rhs);
                let is_and = matches!(binop, BinOp::And(_));
                match (left.truthy_const(), is_and) {
                    (Some(true), true) | (Some(false), false) => right,
                    (Some(false), true) | (Some(true), false) => left,
                    _ => {
                        // The left value only survives when it is falsy for
                        // `and` (boolean results of checks carry no data).
                        let keep_left = if is_and {
                            matches!(left.kind, Kind::Bool(_) | Kind::Nil) && !left.is_tainted()
                        } else {
                            false
                        };
                        if keep_left {
                            let mut v = right;
                            v.kind = match v.kind {
                                Kind::Bool(b) => Kind::Bool(b),
                                _ => Kind::Unknown,
                            };
                            v
                        } else if is_and {
                            // Only `false`/`nil` can come out of the left side of
                            // `and`: those values are harmless booleans.
                            let mut falsy = left.clone();
                            falsy.add_checks(check::TYPE_BOOLEAN);
                            falsy.join(&right)
                        } else {
                            // `cond and "yes" or "no"`: when the middle value is
                            // truthy, the result is one of the two branches.
                            if let Expression::BinaryOperator {
                                binop: BinOp::And(_),
                                rhs: middle,
                                ..
                            } = unwrap_expr(lhs)
                            {
                                let middle = self.peek(frame, state, middle);
                                if middle.truthy_const() == Some(true) && !middle.is_tainted() {
                                    return middle.join(&right);
                                }
                            }
                            left.join(&right)
                        }
                    }
                }
            }
            BinOp::TwoDots(_) => {
                let left = self.eval(frame, state, lhs);
                let right = self.eval(frame, state, rhs);
                self.concat(&left, &right)
            }
            BinOp::TwoEqual(_)
            | BinOp::TildeEqual(_)
            | BinOp::LessThan(_)
            | BinOp::LessThanEqual(_)
            | BinOp::GreaterThan(_)
            | BinOp::GreaterThanEqual(_) => {
                let _ = self.eval(frame, state, lhs);
                let _ = self.eval(frame, state, rhs);
                Value::of(Kind::Bool(None))
            }
            _ => {
                let left = self.eval(frame, state, lhs);
                let right = self.eval(frame, state, rhs);
                let mut v = self.arith(&left, &right);
                if let (Kind::Number(Some(a)), Kind::Number(Some(b))) = (&left.kind, &right.kind) {
                    v.kind = Kind::Number(match binop {
                        BinOp::Plus(_) => Some(a + b),
                        BinOp::Minus(_) => Some(a - b),
                        BinOp::Star(_) => Some(a * b),
                        BinOp::Slash(_) => Some(a / b),
                        _ => None,
                    });
                }
                v
            }
        }
    }

    pub(crate) fn arith(&self, left: &Value<'a>, right: &Value<'a>) -> Value<'a> {
        let mut v = Value::of(Kind::Number(None));
        for value in [left, right] {
            for flow in &value.flows {
                v.add_flows([Flow {
                    raw: false,
                    ..flow.clone()
                }]);
            }
        }
        v
    }

    pub(crate) fn concat(&self, left: &Value<'a>, right: &Value<'a>) -> Value<'a> {
        let kind = match (left.str_const(), right.str_const(), &left.kind, &right.kind) {
            (Some(a), Some(b), _, _) => Kind::Str(Some(Rc::from(format!("{a}{b}").as_str()))),
            _ => Kind::Str(None),
        };
        let mut v = Value::of(kind);
        for value in [left, right] {
            for flow in value.deep_flows() {
                v.add_flows([Flow { raw: false, ..flow }]);
            }
        }
        v
    }

    pub(crate) fn eval_var(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        var: &'a Var,
    ) -> Value<'a> {
        match var {
            Var::Name(token) => self.read_name(frame, state, &token_name(token)),
            Var::Expression(var_expr) => {
                let suffixes: Vec<&'a Suffix> = var_expr.suffixes().collect();
                self.eval_suffixed(frame, state, var_expr.prefix(), suffixes, false)
                    .into_iter()
                    .next()
                    .unwrap_or_else(Value::nil)
            }
            _ => Value::unknown(),
        }
    }

    pub(crate) fn read_name(&self, frame: &Frame<'a>, state: &State<'a>, name: &str) -> Value<'a> {
        if let Some(id) = frame.lookup(name) {
            if let Some(v) = state.vars.get(&id) {
                return v.clone();
            }
            if let Some(v) = self.statics.get(&frame.file).and_then(|s| s.get(&id)) {
                return v.clone();
            }
            return Value::unknown().with_path(name);
        }
        let gid = global_id(frame.file, name);
        if let Some(v) = state.vars.get(&gid) {
            return v.clone();
        }
        if let Some(v) = self.statics.get(&frame.file).and_then(|s| s.get(&gid)) {
            return v.clone();
        }
        self.global_value(frame.file, name)
    }

    fn global_value(&self, file: usize, name: &str) -> Value<'a> {
        match name {
            "game" => Value::obj(ObjClass::Game, Some(Vec::new()), "game"),
            "workspace" | "Workspace" => Value::obj(
                ObjClass::Service(Rc::from("Workspace")),
                Some(vec!["Workspace".into()]),
                "workspace",
            ),
            "script" => Value::obj(
                ObjClass::Script,
                Some(self.project.files[file].instance_path.clone()),
                "script",
            ),
            "_G" | "shared" => Value::obj(ObjClass::GlobalEnv, None, name),
            _ => {
                if let Some(builtin) = global_builtin(name) {
                    return Value::of(Kind::Func(Rc::new(vec![Func::Builtin(builtin)])))
                        .with_path(name);
                }
                if LIBRARIES.contains(&name) {
                    return Value::obj(ObjClass::Library(Rc::from(name)), None, name);
                }
                Value::unknown().with_path(name)
            }
        }
    }

    /// Evaluates `prefix` followed by `suffixes` (indexing and calls).
    pub(crate) fn eval_suffixed(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        prefix: &'a Prefix,
        suffixes: Vec<&'a Suffix>,
        statement: bool,
    ) -> Vec<Value<'a>> {
        let (mut current, mut static_path): (Value<'a>, Option<(u64, String)>) = match prefix {
            Prefix::Name(token) => {
                let name = token_name(token);
                let value = self.read_name(frame, state, &name);
                let root = frame.lookup(&name);
                (value, root.map(|id| (id, String::new())))
            }
            Prefix::Expression(expr) => (self.eval(frame, state, expr), None),
            _ => (Value::unknown(), None),
        };
        let root_id = match prefix {
            Prefix::Name(token) => frame.lookup(&token_name(token)),
            _ => None,
        };
        let mut results = vec![current.clone()];
        let mut display = compact(prefix);
        let mut callee_path: Option<Vec<String>> = match prefix {
            Prefix::Name(token) => Some(vec![token_name(token)]),
            _ => None,
        };
        let count = suffixes.len();
        let mut last_client_argument: Option<Target> = None;
        // `obj.Method` just read: the receiver, its text and the method name.
        let mut dot_method: Option<(Value<'a>, String, String)> = None;
        for (i, suffix) in suffixes.iter().enumerate() {
            let is_last = i + 1 == count;
            let receiver = dot_method.take();
            match suffix {
                Suffix::Index(index) => {
                    let loc = self.loc(frame.file, *suffix);
                    if let Index::Dot { name, .. } = index {
                        let n = token_name(name);
                        if n.starts_with(|c: char| c.is_ascii_uppercase()) {
                            dot_method = Some((current.clone(), display.clone(), n));
                        }
                    }
                    let key = match index {
                        Index::Dot { name, .. } => {
                            let n = token_name(name);
                            if let Some(p) = callee_path.as_mut() {
                                p.push(n.clone());
                            }
                            Key::Name(Rc::from(n.as_str()))
                        }
                        Index::Brackets { expression, .. } => {
                            let k = self.eval(frame, state, expression);
                            last_client_argument = self.client_variable(frame, expression, &k);
                            match k.str_const() {
                                Some(s) if !k.is_tainted() => {
                                    if let Some(p) = callee_path.as_mut() {
                                        p.push(s.to_string());
                                    }
                                    Key::Name(Rc::from(s))
                                }
                                _ => {
                                    callee_path = None;
                                    let target = self.target_of(frame, expression);
                                    Key::Dynamic(k, target)
                                }
                            }
                        }
                        _ => Key::Name(Rc::from("?")),
                    };
                    static_path = match (static_path, &key) {
                        (Some((id, path)), Key::Name(n)) => Some((
                            id,
                            if path.is_empty() {
                                n.to_string()
                            } else {
                                format!("{path}.{n}")
                            },
                        )),
                        _ => None,
                    };
                    let key_display = compact(*suffix);
                    // `data[name]` with `name == "Gems"`: the path names the
                    // field, so that currencies and saved data are recognised.
                    let constant_from_variable = match (index, &key) {
                        (Index::Brackets { expression, .. }, Key::Name(n))
                            if !matches!(unwrap_expr(expression), Expression::String(_)) =>
                        {
                            Some(n.clone())
                        }
                        _ => None,
                    };
                    let base_path = current.path.clone();
                    current = self.index_value(&current, key, loc, &display, &key_display);
                    if let Some(n) = constant_from_variable {
                        let base = base_path.as_deref().unwrap_or(display.as_str());
                        current.path = Some(Rc::from(format!("{base}.{n}").as_str()));
                    }
                    display.push_str(&key_display);
                    if let Some((id, path)) = &static_path {
                        if let Some(checks) = state.path_facts.get(&(*id, Rc::from(path.as_str())))
                        {
                            current.add_checks(*checks);
                        }
                    }
                    results = vec![current.clone()];
                }
                Suffix::Call(call) => {
                    static_path = None;
                    // Underline from the start of the called expression.
                    let mut loc = self.loc(frame.file, *suffix);
                    let start = super::span_of(prefix);
                    if start.line > 0 {
                        loc.span.line = start.line;
                        loc.span.column = start.column;
                    }
                    match call {
                        Call::AnonymousCall(args) => {
                            let arg_exprs = args_exprs(args);
                            let arg_values = self.eval_args(frame, state, args);
                            last_client_argument = match (arg_exprs.first(), arg_values.first()) {
                                (Some(e), Some(v)) => self.client_variable(frame, e, v),
                                _ => None,
                            };
                            // `obj.Method(obj, ...)` is `obj:Method(...)`.
                            let method_call = receiver.filter(|(_, receiver_display, _)| {
                                arg_exprs.first().map(|e| compact(*e)).as_ref()
                                    == Some(receiver_display)
                            });
                            results = if let Some((receiver, receiver_display, name)) = method_call
                            {
                                self.call_method(
                                    frame,
                                    state,
                                    &receiver,
                                    &name,
                                    arg_values[1..].to_vec(),
                                    &arg_exprs[1..],
                                    callee_path.as_deref(),
                                    &receiver_display,
                                    loc,
                                    statement && is_last,
                                )
                            } else {
                                self.call_value(
                                    frame,
                                    state,
                                    &current,
                                    arg_values,
                                    &arg_exprs,
                                    callee_path.as_deref(),
                                    &display,
                                    loc,
                                    statement && is_last,
                                )
                            };
                            display.push_str("(...)");
                        }
                        Call::MethodCall(method) => {
                            let name = token_name(method.name());
                            let arg_exprs = args_exprs(method.args());
                            let arg_values = self.eval_args(frame, state, method.args());
                            last_client_argument = match (arg_exprs.first(), arg_values.first()) {
                                (Some(e), Some(v)) => self.client_variable(frame, e, v),
                                _ => None,
                            };
                            let mut path = callee_path.clone();
                            if let Some(p) = path.as_mut() {
                                p.push(name.clone());
                            }
                            let mut method_loc = self.loc(frame.file, method.name());
                            let end = super::span_of(method.args());
                            if end.end_line > 0 {
                                method_loc.span.end_line = end.end_line;
                                method_loc.span.end_column = end.end_column;
                            }
                            let _ = loc;
                            results = self.call_method(
                                frame,
                                state,
                                &current,
                                &name,
                                arg_values,
                                &arg_exprs,
                                path.as_deref(),
                                &display,
                                method_loc,
                                statement && is_last,
                            );
                            display.push_str(&format!(":{name}(...)"));
                        }
                        _ => {}
                    }
                    callee_path = None;
                    current = results.first().cloned().unwrap_or_else(Value::nil);
                }
                _ => {}
            }
        }
        // Remember which client variable a derived value came from.
        if count > 0 {
            if let (Some(id), Some(first)) = (root_id, results.first_mut()) {
                if first.is_tainted() && first.origin.is_none() {
                    first.origin = Some(Target::Var(id));
                }
            }
            // `Players:GetPlayerFromCharacter(model)`, `PlotOwners[plot]`: a
            // server value computed from a client Instance variable.
            if let Some(first) = results.first_mut() {
                if first.origin.is_none() && !first.is_tainted() {
                    first.origin = last_client_argument.take();
                }
            }
        }
        results
    }

    /// `Target::Var` of `expr` when it is a local variable holding client data.
    fn client_variable(
        &self,
        frame: &Frame<'a>,
        expr: &'a Expression,
        value: &Value<'a>,
    ) -> Option<Target> {
        if !value.is_tainted() {
            return None;
        }
        match unwrap_expr(expr) {
            Expression::Var(Var::Name(token)) => frame.lookup(&token_name(token)).map(Target::Var),
            // `GetPlayerFromCharacter(accessory.Parent)`: the parent decides
            // who owns the variable.
            Expression::Var(Var::Expression(var)) => {
                let Prefix::Name(token) = var.prefix() else {
                    return None;
                };
                let parents = var.suffixes().all(|s| {
                    matches!(s, Suffix::Index(Index::Dot { name, .. }) if token_name(name) == "Parent")
                });
                if parents {
                    frame.lookup(&token_name(token)).map(Target::Var)
                } else {
                    None
                }
            }
            _ => None,
        }
    }

    pub(crate) fn eval_args(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        args: &'a FunctionArgs,
    ) -> Vec<Value<'a>> {
        match args {
            FunctionArgs::Parentheses { arguments, .. } => {
                let exprs: Vec<&'a Expression> = arguments.iter().collect();
                self.eval_list(frame, state, &exprs)
            }
            FunctionArgs::String(token) => vec![Value::of(Kind::Str(string_literal(token)))],
            FunctionArgs::TableConstructor(table) => vec![self.eval_table(frame, state, table)],
            _ => Vec::new(),
        }
    }

    /// `base.key` / `base[key]`.
    pub(crate) fn index_value(
        &self,
        base: &Value<'a>,
        key: Key<'a>,
        _loc: Loc,
        base_display: &str,
        key_display: &str,
    ) -> Value<'a> {
        let path: Rc<str> = match &base.path {
            Some(p) => Rc::from(format!("{p}{key_display}").as_str()),
            None => Rc::from(format!("{base_display}{key_display}").as_str()),
        };
        // Untrusted base: the result is (part of) what the client sent.
        let mut result = match (&base.kind, &key) {
            (Kind::Table(table), Key::Name(name)) => table
                .fields
                .get(name)
                .cloned()
                .or_else(|| table.dynamic.as_deref().cloned())
                .unwrap_or_else(Value::nil),
            (Kind::Table(table), Key::Dynamic(..)) => {
                let mut acc: Option<Value<'a>> = None;
                for v in table.fields.values().chain(table.dynamic.as_deref()) {
                    acc = Some(match acc {
                        None => v.clone(),
                        Some(a) => a.join(v),
                    });
                }
                // An empty table may be filled elsewhere (`sessions[player]`
                // set in a PlayerAdded handler): the entry is unknown, not nil.
                acc.unwrap_or_else(Value::unknown)
            }
            (Kind::Obj(obj), Key::Name(name)) => self.obj_member(obj, name, base),
            (Kind::Obj(obj), Key::Dynamic(..)) if obj.class == ObjClass::GlobalEnv => {
                Value::unknown()
            }
            (Kind::Validator(v), Key::Name(_)) => Value::of(Kind::Validator(v.clone())),
            _ => Value::unknown(),
        };
        if result.path.is_none() || !matches!(base.kind, Kind::Table(_)) {
            result.path = Some(path);
        }
        result.player_rel |= base.player_rel;
        // Fields of untrusted values are untrusted. Components of a bounded
        // vector are bounded, and `.Unit` has length 1.
        let component = matches!(key.name(), Some("X" | "Y" | "Z" | "Magnitude"));
        let unit = key.name() == Some("Unit");
        for flow in &base.flows {
            let instance = flow.any(check::TYPE_INSTANCE) || flow.instance_data;
            let mut inherited = check::INHERITED_BY_FIELDS;
            if component {
                inherited |= check::BOUNDS | check::NAN_SAFE;
            }
            let extra = if unit {
                check::BOUNDS | check::TYPE_OTHER
            } else {
                0
            };
            result.add_flows([Flow {
                checks: (flow.checks & inherited) | extra,
                raw: flow.raw,
                instance_data: instance && flow.raw || flow.instance_data,
                ..flow.clone()
            }]);
        }
        if let Key::Dynamic(key_value, target) = &key {
            if key_value.is_tainted() {
                let global_env = matches!(base.class(), Some(ObjClass::GlobalEnv));
                if global_env {
                    // `_G[name]`, `getfenv()[name]`: the client picks any global.
                    result.add_flows(key_value.flows.iter().map(|f| Flow {
                        raw: false,
                        ..f.clone()
                    }));
                    result.kind = Kind::Unknown;
                } else if !base.is_tainted() {
                    // A server collection looked up with an untrusted key: the
                    // result is server data, and proves the key is allowed.
                    result.witness = target.clone();
                }
            }
        }
        result
    }

    fn obj_member(&self, obj: &Obj, name: &str, base: &Value<'a>) -> Value<'a> {
        let child_instance = |n: &str| -> Option<Vec<String>> {
            obj.instance.as_ref().map(|p| {
                let mut v = (**p).clone();
                if n == "Parent" {
                    v.pop();
                } else {
                    v.push(n.to_string());
                }
                v
            })
        };
        match &obj.class {
            ObjClass::Library(library) => {
                let builtin = library_member(library, name);
                Value::of(Kind::Func(Rc::new(vec![Func::Builtin(builtin)])))
            }
            ObjClass::TLibrary => Value::of(Kind::Validator(Rc::new(super::calls::t_member(name)))),
            ObjClass::Game if is_service_name(name) => Value::obj(
                ObjClass::Service(Rc::from(name)),
                Some(vec![name.to_string()]),
                name,
            ),
            _ => {
                let instance = child_instance(name);
                let mut v = Value::of(Kind::Obj(Rc::new(Obj {
                    class: ObjClass::Unknown,
                    instance: instance.map(Rc::new),
                })));
                v.player_rel = base.player_rel || obj.class == ObjClass::Player;
                v
            }
        }
    }
}

/// Copy of `value` with `keys` set to `field` (tables only).
fn with_field<'a>(value: &Value<'a>, keys: &[Rc<str>], field: Value<'a>) -> Option<Value<'a>> {
    let mut table = match &value.kind {
        Kind::Table(table) => (**table).clone(),
        // `local Service = Knit.CreateService({...})` then `function Service:Buy()`:
        // keep the methods even though the object itself is unknown.
        Kind::Unknown
            if !value.is_tainted() && keys.len() == 1 && matches!(field.kind, Kind::Func(_)) =>
        {
            Table::default()
        }
        _ => return None,
    };
    let (first, rest) = keys.split_first()?;
    if rest.is_empty() {
        table.fields.insert(first.clone(), field);
    } else {
        let inner = table.fields.get(first)?;
        let updated = with_field(inner, rest, field)?;
        table.fields.insert(first.clone(), updated);
    }
    let mut out = value.clone();
    out.kind = Kind::Table(Rc::new(table));
    Some(out)
}

fn with_dynamic<'a>(
    value: &Value<'a>,
    keys: &[Rc<str>],
    key: Value<'a>,
    field: Value<'a>,
) -> Option<Value<'a>> {
    let Kind::Table(table) = &value.kind else {
        return None;
    };
    let mut table = (**table).clone();
    match keys.split_first() {
        None => {
            let mut field = field;
            field.add_flows(key.flows);
            table.dynamic = Some(Box::new(match table.dynamic.take() {
                Some(d) => d.join(&field),
                None => field,
            }));
        }
        Some((first, rest)) => {
            let inner = table.fields.get(first)?;
            let updated = with_dynamic(inner, rest, key, field)?;
            table.fields.insert(first.clone(), updated);
        }
    }
    let mut out = value.clone();
    out.kind = Kind::Table(Rc::new(table));
    Some(out)
}
