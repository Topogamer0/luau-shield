//! Abstract values manipulated by the interpreter.
//!
//! A [`Value`] has a *kind* (what we know about the value itself: a number
//! literal, a table, a function, a Roblox object reached through a known
//! path...) and a list of [`Flow`]s: one per piece of untrusted data that may
//! be contained in the value. A value without flows is trusted.

use crate::finding::Loc;
use full_moon::ast::{Expression, FunctionBody};
use std::collections::BTreeMap;
use std::fmt;
use std::rc::Rc;

/// Facts established about an untrusted value by checks in the code.
pub type Checks = u32;

pub mod check {
    use super::Checks;

    pub const TYPE_NUMBER: Checks = 1 << 0;
    pub const TYPE_STRING: Checks = 1 << 1;
    pub const TYPE_BOOLEAN: Checks = 1 << 2;
    pub const TYPE_INSTANCE: Checks = 1 << 3;
    pub const TYPE_TABLE: Checks = 1 << 4;
    /// Some other type check (Vector3, CFrame, EnumItem, custom "type" sanitizer).
    pub const TYPE_OTHER: Checks = 1 << 5;
    pub const LOWER: Checks = 1 << 6;
    pub const UPPER: Checks = 1 << 7;
    pub const NAN_SAFE: Checks = 1 << 8;
    pub const ALLOWLIST: Checks = 1 << 9;
    pub const PATTERN: Checks = 1 << 10;
    pub const LENGTH: Checks = 1 << 11;
    pub const OWNERSHIP: Checks = 1 << 12;
    pub const FILTERED: Checks = 1 << 13;
    pub const ENCODED: Checks = 1 << 14;
    /// Validated by a validator function: every rule accepts it.
    pub const VALIDATED: Checks = 1 << 15;

    pub const ANY_TYPE: Checks =
        TYPE_NUMBER | TYPE_STRING | TYPE_BOOLEAN | TYPE_INSTANCE | TYPE_TABLE | TYPE_OTHER;
    pub const BOUNDS: Checks = LOWER | UPPER;
    pub const ALL: Checks = (1 << 16) - 1;
    /// Not a check of the value: the code only runs for players who passed a
    /// permission guard (`if not Admins.isAdmin(player) then return end`).
    /// Findings on such values are downgraded to `info`.
    pub const PRIVILEGED: Checks = 1 << 16;
    /// Not a check either: while summarising a function, its bounds or
    /// allow-list came from another parameter (`math.clamp(v, 1, max)`).
    /// They prove nothing at a call where that argument is client data.
    pub const RELATIVE: Checks = 1 << 17;
    /// Facts that can be relative to another value (see `RELATIVE`).
    pub const RELATIVE_FACTS: Checks = BOUNDS | ALLOWLIST | OWNERSHIP | LENGTH;
    /// Facts that survive reading a field of a checked value.
    pub const INHERITED_BY_FIELDS: Checks = VALIDATED | OWNERSHIP | ALLOWLIST | PRIVILEGED;
    /// Facts that survive any transformation of the value.
    pub const KEPT: Checks = VALIDATED | ALLOWLIST | PRIVILEGED;
    /// Facts that make every rule happy.
    pub const TRUSTED: Checks = VALIDATED | ALLOWLIST;
}

pub fn checks_from_names(names: &[&str]) -> Result<Checks, String> {
    let mut checks = 0;
    for name in names {
        checks |= match name.to_ascii_lowercase().as_str() {
            "all" => check::VALIDATED,
            "type" => check::TYPE_OTHER,
            "number" => check::TYPE_NUMBER,
            "string" => check::TYPE_STRING,
            "boolean" => check::TYPE_BOOLEAN,
            "instance" => check::TYPE_INSTANCE,
            "lower" => check::LOWER,
            "upper" => check::UPPER,
            "range" | "bounds" => check::BOUNDS,
            "nan" => check::NAN_SAFE,
            "allowlist" => check::ALLOWLIST,
            "pattern" => check::PATTERN,
            "length" => check::LENGTH,
            "ownership" => check::OWNERSHIP,
            "filtered" => check::FILTERED,
            "encoded" => check::ENCODED,
            other => {
                return Err(format!(
                    "unknown check `{other}` (expected all, type, number, string, boolean, instance, lower, upper, range, nan, allowlist, pattern, length, ownership, filtered or encoded)"
                ));
            }
        };
    }
    Ok(checks)
}

/// Human description of a set of checks.
pub fn describe_checks(checks: Checks) -> Vec<&'static str> {
    let mut out = Vec::new();
    let table: [(Checks, &str); 16] = [
        (check::VALIDATED, "validated"),
        (check::ALLOWLIST, "allow-listed"),
        (check::TYPE_NUMBER, "type number"),
        (check::TYPE_STRING, "type string"),
        (check::TYPE_BOOLEAN, "type boolean"),
        (check::TYPE_INSTANCE, "type Instance"),
        (check::TYPE_TABLE, "type table"),
        (check::TYPE_OTHER, "type"),
        (check::LOWER, "lower bound"),
        (check::UPPER, "upper bound"),
        (check::NAN_SAFE, "NaN rejected"),
        (check::PATTERN, "pattern"),
        (check::LENGTH, "length limit"),
        (check::OWNERSHIP, "ownership/location"),
        (check::FILTERED, "filtered"),
        (check::ENCODED, "url-encoded"),
    ];
    for (flag, name) in table {
        if checks & flag != 0 {
            out.push(name);
        }
    }
    out
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SourceKind {
    /// Parameter of an `OnServerEvent` / `OnServerInvoke` handler.
    RemoteParameter,
    /// Values returned by `InvokeClient`.
    InvokeClientResult,
    /// `Player.Chatted` message.
    ChatMessage,
    /// Parameter of a function matched by a configured source pattern.
    Custom,
    /// Placeholder used while summarising validation functions.
    Probe,
}

/// Where a piece of untrusted data enters the program.
#[derive(Debug)]
pub struct Source {
    pub id: u32,
    pub kind: SourceKind,
    /// Parameter / variable name (`amount`).
    pub name: String,
    /// `parameter #2 \`amount\` of BuyItem.OnServerEvent`.
    pub description: String,
    pub loc: Loc,
    /// Type annotation written on the parameter, if any (it is not a check!).
    pub annotation: Option<String>,
}

/// One step of the path followed by the data (persistent linked list).
#[derive(Debug)]
pub struct StepNode {
    pub loc: Loc,
    pub note: Rc<str>,
    pub prev: Option<Rc<StepNode>>,
    pub len: usize,
}

pub const MAX_STEPS: usize = 24;

/// A piece of untrusted data contained in a value.
#[derive(Clone, Debug)]
pub struct Flow {
    pub source: Rc<Source>,
    pub steps: Option<Rc<StepNode>>,
    pub checks: Checks,
    /// The value is (part of) what the client sent, unmodified: if it is an
    /// Instance, it is the Instance the client chose.
    pub raw: bool,
    /// The value was read from an Instance chosen by the client (server data,
    /// but the client decides which object it comes from).
    pub instance_data: bool,
    /// The last function named like a sanitizer (`Look.sanitize`) that
    /// returned this value: findings suggest declaring it in the configuration.
    pub via: Option<Rc<Via>>,
    /// The permission guard (`Admins.isAdmin(player)`) that made this flow
    /// `PRIVILEGED`, named in downgraded findings.
    pub guard: Option<Rc<str>>,
}

/// A sanitizer-like function a value went through.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Via {
    /// How the function was called (`Look.sanitize`).
    pub name: Rc<str>,
    /// luau-shield analysed its body (otherwise it could not be resolved or
    /// was too deep to follow).
    pub analysed: bool,
    /// The checks its results had when it returned.
    pub made: Checks,
}

impl Flow {
    pub fn new(source: Rc<Source>) -> Flow {
        Flow {
            source,
            steps: None,
            checks: 0,
            raw: true,
            instance_data: false,
            via: None,
            guard: None,
        }
    }

    pub fn with_step(&self, loc: Loc, note: impl Into<Rc<str>>) -> Flow {
        let note = note.into();
        if let Some(last) = &self.steps {
            if last.loc.span.line == loc.span.line && last.loc.file == loc.file && last.note == note
            {
                return self.clone();
            }
            if last.len >= MAX_STEPS {
                return self.clone();
            }
        }
        let len = self.steps.as_ref().map_or(0, |s| s.len) + 1;
        Flow {
            steps: Some(Rc::new(StepNode {
                loc,
                note,
                prev: self.steps.clone(),
                len,
            })),
            ..self.clone()
        }
    }

    /// Steps from the source to the most recent one.
    pub fn step_list(&self) -> Vec<(Loc, Rc<str>)> {
        let mut out = Vec::new();
        let mut node = self.steps.as_ref();
        while let Some(n) = node {
            out.push((n.loc, n.note.clone()));
            node = n.prev.as_ref();
        }
        out.reverse();
        out
    }

    pub fn has(&self, checks: Checks) -> bool {
        self.checks & checks == checks
    }

    pub fn any(&self, checks: Checks) -> bool {
        self.checks & checks != 0
    }

    fn same(&self, other: &Flow) -> bool {
        self.source.id == other.source.id
            && self.checks == other.checks
            && self.raw == other.raw
            && self.instance_data == other.instance_data
    }
}

pub const MAX_FLOWS: usize = 8;

/// Functions a value can hold (a handler table connected in a loop holds
/// all of its handlers).
pub const MAX_FUNCS: usize = 64;

/// A function value.
#[derive(Clone, Debug)]
pub enum Func<'a> {
    Closure(Rc<Closure<'a>>),
    Builtin(Builtin),
}

impl Func<'_> {
    fn ptr_eq(&self, other: &Self) -> bool {
        match (self, other) {
            (Func::Closure(a), Func::Closure(b)) => Rc::ptr_eq(a, b) || a.key() == b.key(),
            (Func::Builtin(a), Func::Builtin(b)) => a == b,
            _ => false,
        }
    }
}

pub struct Closure<'a> {
    pub file: usize,
    pub body: &'a FunctionBody,
    pub name: Rc<str>,
    pub loc: Loc,
    /// Declared with `:` (implicit `self`).
    pub is_method: bool,
    /// Names visible where the function was created.
    pub captured: Rc<Scope>,
}

impl Closure<'_> {
    /// Identity of the function definition (not of this closure instance).
    pub fn key(&self) -> (usize, usize) {
        (self.file, self.body as *const FunctionBody as usize)
    }
}

impl fmt::Debug for Closure<'_> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "Closure({})", self.name)
    }
}

/// Lexical scope: names -> variable ids (persistent, cheap to clone).
#[derive(Debug, Default)]
pub struct Scope {
    pub names: BTreeMap<Rc<str>, VarId>,
}

pub type VarId = u64;

/// Library functions with a dedicated model.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Builtin {
    Typeof,
    Type,
    Tonumber,
    Tostring,
    Assert,
    Error,
    Pcall,
    Xpcall,
    Select,
    Require,
    Loadstring,
    Getfenv,
    Setfenv,
    Pairs,
    Ipairs,
    Next,
    Unpack,
    Rawget,
    Rawset,
    Rawequal,
    Setmetatable,
    Getmetatable,
    Print,
    /// `task.spawn` / `task.defer` / `task.delay` / `coroutine.wrap` / `spawn` / `delay`...
    Spawn,
    /// `coroutine.yield()`.
    Yield,
    Wait,
    TableInsert,
    TableFind,
    TableConcat,
    TableClone,
    TableFreeze,
    TableRemove,
    TableSort,
    TableUnpack,
    TableCreate,
    MathClamp,
    MathMin,
    MathMax,
    MathAbs,
    MathFloor,
    /// Other pure math functions (result derived from the arguments).
    MathOther,
    StringLen,
    StringMatch,
    StringFind,
    StringFormat,
    StringByte,
    /// `string.sub(s, i, j)`: with server bounds, caps the length.
    StringSub,
    /// Other string functions returning a derived string.
    StringOther,
    InstanceNew,
    /// `os.clock`, `tick`, `time`, `os.time`, `DateTime.now`...
    Clock,
    /// Pure constructor (Vector3.new, CFrame.new, Color3.new, UDim2.new...).
    Constructor,
    /// Unknown library function: the result is derived from the arguments.
    Derive,
}

/// Something we know about a Roblox object or a value reached through a path.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ObjClass {
    Unknown,
    Game,
    /// A service, by name.
    Service(Rc<str>),
    DataStore,
    MemoryStore,
    /// The player who fired the remote (trusted).
    Player,
    /// The `script` global.
    Script,
    /// A TextFilterResult (output of FilterStringAsync).
    TextFilterResult,
    /// The `t` runtime type-checking library.
    TLibrary,
    /// `_G`, `shared`, `getfenv()`: indexing them with client data picks any global.
    GlobalEnv,
    /// A global library table (`math`, `string`, `Vector3`...).
    Library(Rc<str>),
}

#[derive(Clone, Debug)]
pub struct Obj {
    pub class: ObjClass,
    /// Instance path from the DataModel root, when it can be resolved.
    pub instance: Option<Rc<Vec<String>>>,
}

/// A table literal, tracked by value.
#[derive(Clone, Debug, Default)]
pub struct Table<'a> {
    pub fields: BTreeMap<Rc<str>, Value<'a>>,
    /// Values stored under unknown keys (arrays, dynamic keys).
    pub dynamic: Option<Box<Value<'a>>>,
    /// Analysis frame that constructed the table, while it has not escaped.
    pub fresh_frame: Option<u32>,
}

/// What a value is.
#[derive(Clone, Debug, Default)]
pub enum Kind<'a> {
    #[default]
    Unknown,
    Nil,
    Bool(Option<bool>),
    Number(Option<f64>),
    Str(Option<Rc<str>>),
    Table(Rc<Table<'a>>),
    Func(Rc<Vec<Func<'a>>>),
    Obj(Rc<Obj>),
    /// A runtime type checker (from the `t` library).
    Validator(Rc<Validator>),
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Validator {
    /// Facts about the first argument when the check passes.
    pub checks: Checks,
    /// Facts per argument (`t.tuple`); overrides `checks` when not empty.
    pub positional: Vec<Checks>,
    /// Facts about fields of the first argument (`t.interface`).
    pub fields: Vec<(Rc<str>, Checks)>,
    /// `t.strict(...)`: errors instead of returning false.
    pub asserting: bool,
    /// The value is the `t.something` constructor, not a checker yet.
    pub constructor: Option<Rc<str>>,
}

/// Something a refinement can apply to: a variable or a field path below one.
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum Target {
    Var(VarId),
    Path(VarId, Rc<str>),
}

#[derive(Clone, Debug, Default)]
pub struct Value<'a> {
    pub kind: Kind<'a>,
    pub flows: Vec<Flow>,
    /// Display path, e.g. `player.leaderstats.Coins`.
    pub path: Option<Rc<str>>,
    /// Derived from the trusted player object.
    pub player_rel: bool,
    /// The value was looked up in a server collection with an untrusted key:
    /// proving it is non-nil allow-lists that key.
    pub witness: Option<Target>,
    /// The expression a local was initialised with, when it is a check
    /// (`local ok = isValid(x)`) or a measure (`local d = (a - b).Magnitude`):
    /// testing the local tests that expression.
    pub defined_by: Option<&'a Expression>,
    /// The client Instance variable this value was read from
    /// (`local owner = car:FindFirstChild("Owner")`): verifying the value's
    /// ownership also verifies the Instance.
    pub origin: Option<Target>,
    /// luau-shield007: the state expression this local was read from
    /// (`local current = state[player]`), as a state key.
    pub alias: Option<Rc<str>>,
}

impl<'a> Value<'a> {
    pub fn unknown() -> Value<'a> {
        Value::default()
    }

    pub fn of(kind: Kind<'a>) -> Value<'a> {
        Value {
            kind,
            ..Value::default()
        }
    }

    pub fn nil() -> Value<'a> {
        Value::of(Kind::Nil)
    }

    pub fn string(s: &str) -> Value<'a> {
        Value::of(Kind::Str(Some(Rc::from(s))))
    }

    pub fn obj(class: ObjClass, instance: Option<Vec<String>>, path: &str) -> Value<'a> {
        Value {
            kind: Kind::Obj(Rc::new(Obj {
                class,
                instance: instance.map(Rc::new),
            })),
            path: Some(Rc::from(path)),
            ..Value::default()
        }
    }

    pub fn is_tainted(&self) -> bool {
        !self.flows.is_empty()
    }

    pub fn with_path(mut self, path: impl Into<Rc<str>>) -> Value<'a> {
        self.path = Some(path.into());
        self
    }

    pub fn str_const(&self) -> Option<&str> {
        match &self.kind {
            Kind::Str(Some(s)) => Some(s),
            _ => None,
        }
    }

    pub fn obj_ref(&self) -> Option<&Obj> {
        match &self.kind {
            Kind::Obj(o) => Some(o),
            _ => None,
        }
    }

    pub fn class(&self) -> Option<&ObjClass> {
        self.obj_ref().map(|o| &o.class)
    }

    pub fn is_service(&self, name: &str) -> bool {
        matches!(self.class(), Some(ObjClass::Service(s)) if &**s == name)
            || self
                .path
                .as_deref()
                .is_some_and(|p| p == name || p.ends_with(&format!(".{name}")))
    }

    pub fn funcs(&self) -> Vec<Func<'a>> {
        match &self.kind {
            Kind::Func(list) => list.iter().cloned().collect(),
            _ => Vec::new(),
        }
    }

    pub fn table(&self) -> Option<&Table<'a>> {
        match &self.kind {
            Kind::Table(t) => Some(t),
            _ => None,
        }
    }

    pub fn add_flows(&mut self, flows: impl IntoIterator<Item = Flow>) {
        for flow in flows {
            push_flow(&mut self.flows, flow);
        }
    }

    /// All flows in this value, including those nested in table fields.
    pub fn deep_flows(&self) -> Vec<Flow> {
        let mut out = self.flows.clone();
        if let Kind::Table(table) = &self.kind {
            collect_table_flows(table, &mut out, 0);
        }
        out
    }

    /// A value derived from this one through an unknown transformation.
    pub fn derived(&self) -> Value<'a> {
        Value {
            flows: self
                .deep_flows()
                .into_iter()
                .map(|f| Flow { raw: false, ..f })
                .collect(),
            ..Value::default()
        }
    }

    /// Adds a step to every flow.
    pub fn step(mut self, loc: Loc, note: &str) -> Value<'a> {
        if self.flows.is_empty() {
            return self;
        }
        let note: Rc<str> = Rc::from(note);
        for flow in &mut self.flows {
            *flow = flow.with_step(loc, note.clone());
        }
        self
    }

    pub fn add_checks(&mut self, checks: Checks) {
        for flow in &mut self.flows {
            flow.checks |= checks;
        }
    }

    /// Renames the sanitizer-like function recorded as `from` to the way it
    /// was called (`Look.sanitize` declared, `L.sanitize` called).
    pub fn rename_via_deep(&mut self, from: &str, to: &str) {
        self.rename_via_at(from, to, 0);
    }

    fn rename_via_at(&mut self, from: &str, to: &str, depth: usize) {
        for flow in &mut self.flows {
            if let Some(via) = &flow.via {
                if &*via.name == from {
                    flow.via = Some(Rc::new(Via {
                        name: Rc::from(to),
                        analysed: via.analysed,
                        made: via.made,
                    }));
                }
            }
        }
        let renamed = |v: &Value<'a>| {
            v.flows
                .iter()
                .any(|f| f.via.as_ref().is_some_and(|via| &*via.name == from))
        };
        if depth > 6 || !self.any_stored(&renamed) {
            return;
        }
        if let Kind::Table(table) = &self.kind {
            let mut table = (**table).clone();
            for value in table.fields.values_mut() {
                value.rename_via_at(from, to, depth + 1);
            }
            if let Some(dynamic) = table.dynamic.as_mut() {
                dynamic.rename_via_at(from, to, depth + 1);
            }
            self.kind = Kind::Table(Rc::new(table));
        }
    }

    /// Does `pred` hold for a value stored in this table, at any depth up to
    /// `depth_limit`? (Large server tables are shared, not copied, when no
    /// value in them needs a change.)
    pub fn any_stored(&self, pred: &impl Fn(&Value<'a>) -> bool) -> bool {
        self.any_stored_at(pred, 0)
    }

    fn any_stored_at(&self, pred: &impl Fn(&Value<'a>) -> bool, depth: usize) -> bool {
        if depth > 6 {
            return false;
        }
        match &self.kind {
            Kind::Table(table) => table
                .fields
                .values()
                .chain(table.dynamic.as_deref())
                .any(|v| pred(v) || v.any_stored_at(pred, depth + 1)),
            _ => false,
        }
    }

    /// Forgets `defined_by` here and in every stored value.
    pub fn clear_defined_by_deep(&mut self) {
        self.clear_defined_by_at(0);
    }

    fn clear_defined_by_at(&mut self, depth: usize) {
        self.defined_by = None;
        if depth > 6 {
            return;
        }
        if let Kind::Table(table) = &self.kind {
            let needs = table
                .fields
                .values()
                .chain(table.dynamic.as_deref())
                .any(|v| v.defined_by.is_some() || v.any_stored(&|x| x.defined_by.is_some()));
            if needs {
                let mut table = (**table).clone();
                for value in table.fields.values_mut() {
                    value.clear_defined_by_at(depth + 1);
                }
                if let Some(dynamic) = table.dynamic.as_mut() {
                    dynamic.clear_defined_by_at(depth + 1);
                }
                self.kind = Kind::Table(Rc::new(table));
            }
        }
    }

    /// Records that the value (and everything stored in it) was returned by
    /// the sanitizer-like function `via`.
    pub fn set_via_deep(&mut self, via: &Rc<Via>) {
        self.set_via_at(via, 0);
    }

    fn set_via_at(&mut self, via: &Rc<Via>, depth: usize) {
        for flow in &mut self.flows {
            flow.via = Some(via.clone());
        }
        if depth > 6 || !self.any_stored(&|v| !v.flows.is_empty()) {
            return;
        }
        if let Kind::Table(table) = &self.kind {
            let mut table = (**table).clone();
            for value in table.fields.values_mut() {
                value.set_via_at(via, depth + 1);
            }
            if let Some(dynamic) = table.dynamic.as_mut() {
                dynamic.set_via_at(via, depth + 1);
            }
            self.kind = Kind::Table(Rc::new(table));
        }
    }

    /// Marks the value, and everything stored in it, as only reachable after
    /// the permission guard `guard` succeeded.
    pub fn privilege_deep(&mut self, guard: &Rc<str>) {
        self.privilege_at(guard, 0);
    }

    fn privilege_at(&mut self, guard: &Rc<str>, depth: usize) {
        for flow in &mut self.flows {
            flow.checks |= check::PRIVILEGED;
            flow.guard = Some(guard.clone());
        }
        if depth > 6 || !self.any_stored(&|v| !v.flows.is_empty()) {
            return;
        }
        if let Kind::Table(table) = &self.kind {
            let mut table = (**table).clone();
            for value in table.fields.values_mut() {
                value.privilege_at(guard, depth + 1);
            }
            if let Some(dynamic) = table.dynamic.as_mut() {
                dynamic.privilege_at(guard, depth + 1);
            }
            self.kind = Kind::Table(Rc::new(table));
        }
    }

    /// Adds `checks` to the value and to everything stored in it.
    pub fn add_checks_deep(&mut self, checks: Checks) {
        self.add_checks_at(checks, 0);
    }

    fn add_checks_at(&mut self, checks: Checks, depth: usize) {
        self.add_checks(checks);
        if depth > 6 || !self.any_stored(&|v| !v.flows.is_empty()) {
            return;
        }
        if let Kind::Table(table) = &self.kind {
            let mut table = (**table).clone();
            for value in table.fields.values_mut() {
                value.add_checks_at(checks, depth + 1);
            }
            if let Some(dynamic) = table.dynamic.as_mut() {
                dynamic.add_checks_at(checks, depth + 1);
            }
            self.kind = Kind::Table(Rc::new(table));
        }
    }

    pub fn truthy_const(&self) -> Option<bool> {
        match &self.kind {
            Kind::Nil => Some(false),
            Kind::Bool(Some(b)) => Some(*b),
            Kind::Bool(None) | Kind::Unknown => None,
            _ if self.flows.is_empty() => Some(true),
            _ => None,
        }
    }

    /// Least upper bound of two values (used where control flow merges).
    /// Joining `other` into this value changes nothing (a cheap test that
    /// spares copying large tables where control flow merges).
    pub fn absorbs(&self, other: &Value<'a>) -> bool {
        let kind = match (&self.kind, &other.kind) {
            (Kind::Unknown, Kind::Unknown) | (Kind::Nil, Kind::Nil) => true,
            (Kind::Bool(x), Kind::Bool(y)) => x == y,
            (Kind::Number(x), Kind::Number(y)) => x == y,
            (Kind::Str(x), Kind::Str(y)) => x == y,
            (Kind::Table(x), Kind::Table(y)) => Rc::ptr_eq(x, y),
            (Kind::Func(x), Kind::Func(y)) => Rc::ptr_eq(x, y),
            (Kind::Obj(x), Kind::Obj(y)) => {
                Rc::ptr_eq(x, y) || (x.class == y.class && x.instance == y.instance)
            }
            (Kind::Validator(x), Kind::Validator(y)) => Rc::ptr_eq(x, y),
            _ => false,
        };
        kind && self.player_rel == other.player_rel
            && other
                .flows
                .iter()
                .all(|f| self.flows.iter().any(|g| g.same(f)))
            && self.path == other.path
            && self.witness == other.witness
            && match (self.defined_by, other.defined_by) {
                (Some(a), Some(b)) => std::ptr::eq(a, b),
                (None, None) => true,
                _ => false,
            }
            && self.origin == other.origin
            && self.alias == other.alias
    }

    pub fn join(&self, other: &Value<'a>) -> Value<'a> {
        if self.absorbs(other) {
            return self.clone();
        }
        let kind = join_kind(&self.kind, &other.kind);
        let mut flows = self.flows.clone();
        for flow in &other.flows {
            push_flow(&mut flows, flow.clone());
        }
        Value {
            kind,
            flows,
            path: if self.path == other.path {
                self.path.clone()
            } else {
                None
            },
            player_rel: self.player_rel && other.player_rel,
            witness: if self.witness == other.witness {
                self.witness.clone()
            } else {
                None
            },
            defined_by: match (self.defined_by, other.defined_by) {
                (Some(a), Some(b)) if std::ptr::eq(a, b) => Some(a),
                _ => None,
            },
            origin: if self.origin == other.origin {
                self.origin.clone()
            } else {
                None
            },
            alias: if self.alias == other.alias {
                self.alias.clone()
            } else {
                None
            },
        }
    }
}

fn collect_table_flows(table: &Table<'_>, out: &mut Vec<Flow>, depth: usize) {
    if depth > 6 {
        return;
    }
    let values = table.fields.values().chain(table.dynamic.as_deref());
    for value in values {
        for flow in &value.flows {
            push_flow(out, flow.clone());
        }
        if let Kind::Table(inner) = &value.kind {
            collect_table_flows(inner, out, depth + 1);
        }
    }
}

pub fn push_flow(flows: &mut Vec<Flow>, flow: Flow) {
    if flows.iter().any(|f| f.same(&flow)) {
        return;
    }
    if flows.len() >= MAX_FLOWS {
        // Keep the least checked flow for each source: it decides findings.
        if let Some(existing) = flows
            .iter_mut()
            .find(|f| f.source.id == flow.source.id && f.checks & !flow.checks != 0)
        {
            existing.checks &= flow.checks;
        }
        return;
    }
    flows.push(flow);
}

fn join_kind<'a>(a: &Kind<'a>, b: &Kind<'a>) -> Kind<'a> {
    match (a, b) {
        (Kind::Nil, Kind::Nil) => Kind::Nil,
        (Kind::Bool(x), Kind::Bool(y)) => Kind::Bool(if x == y { *x } else { None }),
        (Kind::Number(x), Kind::Number(y)) => Kind::Number(if x == y { *x } else { None }),
        (Kind::Str(x), Kind::Str(y)) => Kind::Str(if x == y { x.clone() } else { None }),
        (Kind::Table(x), Kind::Table(y)) => {
            if Rc::ptr_eq(x, y) {
                return Kind::Table(x.clone());
            }
            // Equal contents: keep the same table (later joins are cheap).
            let same_dynamic = match (&x.dynamic, &y.dynamic) {
                (Some(a), Some(b)) => a.absorbs(b),
                (None, None) => true,
                _ => false,
            };
            if same_dynamic
                && x.fresh_frame == y.fresh_frame
                && x.fields.len() == y.fields.len()
                && y.fields
                    .iter()
                    .all(|(k, v)| x.fields.get(k).is_some_and(|mine| mine.absorbs(v)))
            {
                return Kind::Table(x.clone());
            }
            let mut fields = x.fields.clone();
            for (k, v) in &y.fields {
                let joined = match fields.get(k) {
                    Some(existing) => existing.join(v),
                    None => v.clone(),
                };
                fields.insert(k.clone(), joined);
            }
            let dynamic = match (&x.dynamic, &y.dynamic) {
                (Some(a), Some(b)) => Some(Box::new(a.join(b))),
                (Some(a), None) | (None, Some(a)) => Some(a.clone()),
                (None, None) => None,
            };
            Kind::Table(Rc::new(Table {
                fields,
                dynamic,
                fresh_frame: if x.fresh_frame == y.fresh_frame {
                    x.fresh_frame
                } else {
                    None
                },
            }))
        }
        (Kind::Func(x), Kind::Func(y)) => {
            let mut list: Vec<Func<'a>> = x.iter().cloned().collect();
            for f in y.iter() {
                if !list.iter().any(|g| g.ptr_eq(f)) && list.len() < MAX_FUNCS {
                    list.push(f.clone());
                }
            }
            Kind::Func(Rc::new(list))
        }
        (Kind::Obj(x), Kind::Obj(y)) => {
            if x.class == y.class && x.instance == y.instance {
                Kind::Obj(x.clone())
            } else if x.class == y.class {
                Kind::Obj(Rc::new(Obj {
                    class: x.class.clone(),
                    instance: None,
                }))
            } else {
                Kind::Unknown
            }
        }
        (Kind::Validator(x), Kind::Validator(y)) if x == y => Kind::Validator(x.clone()),
        // `x or default`: keep what we know about the non-nil side.
        (Kind::Nil, other) | (other, Kind::Nil) => match other {
            Kind::Table(_) | Kind::Func(_) | Kind::Obj(_) => other.clone(),
            _ => Kind::Unknown,
        },
        _ => Kind::Unknown,
    }
}
