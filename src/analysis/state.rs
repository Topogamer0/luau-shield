//! Abstract program state (variables and refinements) and activation frames.

use super::value::{Checks, Closure, Scope, Target, Value, VarId, check};
use std::collections::{BTreeMap, HashMap};
use std::rc::Rc;

/// Values of every variable at one program point.
#[derive(Clone, Debug, Default)]
pub struct State<'a> {
    pub vars: HashMap<VarId, Value<'a>>,
    /// Facts about field paths (`data.amount`), keyed by root variable.
    pub path_facts: HashMap<(VarId, Rc<str>), Checks>,
    /// No normal execution reaches this point (after return/error/break).
    pub dead: bool,
    /// luau-shield007: what the conditions on this path proved about state
    /// expressions (`state[player] == "Playing"`, `busy[player]` is falsy),
    /// keyed by the expression text.
    pub expects: BTreeMap<Rc<str>, Expect>,
    /// luau-shield007: a state expression tested on this path was then
    /// changed so that the same test fails next time (`if state[player] ~=
    /// "Playing" then return end; state[player] = "Menu"`): the request
    /// cannot repeat the work that follows. `Some(true)` when the state is
    /// per player, `Some(false)` for a global flag.
    pub consumed: Option<bool>,
}

/// A literal a state expression is compared with.
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub enum Lit {
    Nil,
    Bool(bool),
    /// Numbers are kept as text so that facts stay comparable.
    Num(Rc<str>),
    Str(Rc<str>),
}

/// What a condition proved about a state expression on one path.
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub enum Expect {
    Truthy,
    Falsy,
    Eq(Lit),
    Ne(Lit),
}

impl Expect {
    /// Does writing `value` (a literal, or `None` when unknown) make the
    /// condition that proved `self` fail from now on?
    pub fn violated_by(&self, value: Option<&Lit>, truthy: Option<bool>) -> bool {
        match self {
            Expect::Truthy => truthy == Some(false),
            Expect::Falsy => truthy == Some(true),
            Expect::Eq(lit) => match value {
                Some(v) => v != lit,
                // Any truthy value differs from nil/false.
                None => matches!(lit, Lit::Nil | Lit::Bool(false)) && truthy == Some(true),
            },
            Expect::Ne(lit) => value == Some(lit),
        }
    }
}

impl<'a> State<'a> {
    pub fn dead() -> State<'a> {
        State {
            dead: true,
            ..State::default()
        }
    }

    /// Merge of two control-flow paths.
    pub fn join(self, other: State<'a>) -> State<'a> {
        if self.dead {
            return other;
        }
        if other.dead {
            return self;
        }
        let mut vars = self.vars;
        let mut other_vars = other.vars;
        for (id, value) in vars.iter_mut() {
            // Variables declared on one path only (block-local) are kept.
            if let Some(theirs) = other_vars.remove(id) {
                *value = value.join(&theirs);
            }
        }
        vars.extend(other_vars);
        let mut path_facts = HashMap::new();
        for (key, checks) in self.path_facts {
            if let Some(theirs) = other.path_facts.get(&key) {
                let both = checks & theirs;
                if both != 0 {
                    path_facts.insert(key, both);
                }
            }
        }
        let expects = self
            .expects
            .into_iter()
            .filter(|(k, e)| other.expects.get(k) == Some(e))
            .collect();
        let consumed = match (self.consumed, other.consumed) {
            (Some(a), Some(b)) => Some(a && b),
            _ => None,
        };
        State {
            vars,
            path_facts,
            dead: false,
            expects,
            consumed,
        }
    }

    pub fn join_all(states: impl IntoIterator<Item = State<'a>>) -> State<'a> {
        states.into_iter().fold(State::dead(), State::join)
    }

    /// Records facts about a target. Variables that only exist in another
    /// module's final state are not refined (the refinement would leak into
    /// paths where it does not hold when states are joined).
    pub fn add_checks(&mut self, target: &Target, checks: Checks) {
        if checks == 0 {
            return;
        }
        match target {
            Target::Var(id) => {
                if let Some(value) = self.vars.get_mut(id) {
                    if checks & check::PRIVILEGED != 0 {
                        value.add_checks_deep(checks);
                    } else {
                        value.add_checks(checks);
                    }
                }
            }
            Target::Path(id, path) => {
                *self.path_facts.entry((*id, path.clone())).or_insert(0) |= checks;
            }
        }
    }

    /// Forget refinements about `id.path...` after an assignment.
    pub fn invalidate_paths(&mut self, id: VarId, prefix: Option<&str>) {
        self.path_facts.retain(|(root, path), _| {
            *root != id
                || prefix
                    .is_some_and(|p| !(path.as_ref() == p || path.starts_with(&format!("{p}."))))
        });
    }
}

/// Facts that hold for some targets.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Facts {
    pub map: BTreeMap<Target, Checks>,
    /// luau-shield007: what holds about state expressions (see `State::expects`).
    pub expects: BTreeMap<Rc<str>, Expect>,
}

impl Facts {
    pub fn single(target: Target, checks: Checks) -> Facts {
        let mut facts = Facts::default();
        facts.add(target, checks);
        facts
    }

    pub fn add(&mut self, target: Target, checks: Checks) {
        if checks != 0 {
            *self.map.entry(target).or_insert(0) |= checks;
        }
    }

    /// Both sets of facts hold.
    pub fn union(mut self, other: &Facts) -> Facts {
        for (target, checks) in &other.map {
            self.add(target.clone(), *checks);
        }
        for (text, expect) in &other.expects {
            self.expects.insert(text.clone(), expect.clone());
        }
        self
    }

    /// Only the facts common to both alternatives hold.
    pub fn intersect(&self, other: &Facts) -> Facts {
        let mut out = Facts::default();
        for (target, checks) in &self.map {
            if let Some(theirs) = other.map.get(target) {
                out.add(target.clone(), checks & theirs);
            }
        }
        for (text, expect) in &self.expects {
            if other.expects.get(text) == Some(expect) {
                out.expects.insert(text.clone(), expect.clone());
            }
        }
        out
    }

    pub fn expect(text: impl Into<Rc<str>>, expect: Expect) -> Facts {
        let mut facts = Facts::default();
        facts.expects.insert(text.into(), expect);
        facts
    }
}

/// What a condition teaches us on each branch.
#[derive(Clone, Debug, Default)]
pub struct Refinement {
    pub on_true: Facts,
    pub on_false: Facts,
}

impl Refinement {
    pub fn negate(self) -> Refinement {
        Refinement {
            on_true: self.on_false,
            on_false: self.on_true,
        }
    }
}

pub struct LoopCtx<'a> {
    pub breaks: Vec<State<'a>>,
    pub continues: Vec<State<'a>>,
}

/// Collects facts about parameters at return points (validator summaries).
pub struct SummaryCollector {
    pub params: Vec<(VarId, u32)>,
    pub truthy: Option<Vec<Checks>>,
    pub exit: Option<Vec<Checks>>,
    pub may_return_truthy: bool,
}

/// What a function guarantees about its parameters.
#[derive(Clone, Debug, Default)]
pub struct Summary {
    /// Facts about each parameter when the function returns a truthy value.
    pub truthy: Vec<Checks>,
    /// Facts about each parameter whenever the function returns normally.
    pub exit: Vec<Checks>,
}

/// What a function returns, in terms of its parameters: the return values
/// computed with one "probe" source per parameter.
pub struct ReturnSummary<'a> {
    /// The probe source of each argument position (`None` for `self`).
    pub probes: Vec<Option<u32>>,
    pub returns: Vec<Value<'a>>,
}

/// One function activation.
pub struct Frame<'a> {
    pub id: u32,
    pub file: usize,
    pub closure: Option<Rc<Closure<'a>>>,
    pub base_scope: Rc<Scope>,
    pub scopes: Vec<BTreeMap<Rc<str>, VarId>>,
    pub returns: Option<Vec<Value<'a>>>,
    pub return_states: Vec<State<'a>>,
    pub varargs: Vec<Value<'a>>,
    /// Untrusted values of unknown count at the end of `...`.
    pub vararg_rest: Option<Value<'a>>,
    pub loops: Vec<LoopCtx<'a>>,
    pub summary: Option<SummaryCollector>,
    /// Name of the function, for messages.
    pub name: Rc<str>,
}

impl<'a> Frame<'a> {
    pub fn lookup(&self, name: &str) -> Option<VarId> {
        for scope in self.scopes.iter().rev() {
            if let Some(id) = scope.get(name) {
                return Some(*id);
            }
        }
        self.base_scope.names.get(name).copied()
    }

    pub fn declare(&mut self, name: &str, id: VarId) {
        if self.scopes.is_empty() {
            self.scopes.push(BTreeMap::new());
        }
        self.scopes
            .last_mut()
            .expect("at least one scope")
            .insert(Rc::from(name), id);
    }

    /// Every name visible here (captured by closures created here).
    pub fn capture(&self) -> Rc<Scope> {
        let mut names = self.base_scope.names.clone();
        for scope in &self.scopes {
            for (name, id) in scope {
                names.insert(name.clone(), *id);
            }
        }
        Rc::new(Scope { names })
    }

    pub fn add_return(&mut self, values: Vec<Value<'a>>) {
        self.returns = Some(match self.returns.take() {
            None => values,
            Some(previous) => {
                let len = previous.len().max(values.len());
                (0..len)
                    .map(|i| {
                        let a = previous.get(i).cloned().unwrap_or_else(Value::nil);
                        let b = values.get(i).cloned().unwrap_or_else(Value::nil);
                        a.join(&b)
                    })
                    .collect()
            }
        });
    }
}
