//! The taint analyzer: an abstract interpreter over the full-moon syntax tree.

mod calls;
mod interp;
mod refine;
pub mod state;
pub mod value;

use crate::config::Config;
use crate::finding::{Finding, FlowStep, Loc, Span};
use crate::project::{Project, RunContext, ScriptKind};
use crate::rules::RuleId;
use full_moon::ast::{FunctionBody, Parameter};
use full_moon::node::Node;
use full_moon::tokenizer::TokenReference;
use state::{Frame, State, Summary};
use std::collections::{HashMap, HashSet};
use std::rc::Rc;
use value::{Closure, Flow, Func, Kind, ObjClass, Source, SourceKind, Value, VarId};

/// Statements interpreted per entry point before giving up on deeper calls.
const ENTRY_BUDGET: usize = 60_000;

#[derive(Default)]
pub struct AnalysisOutput {
    pub findings: Vec<Finding>,
    pub suppressed: usize,
    pub warnings: Vec<String>,
}

pub fn span_of(node: &impl Node) -> Span {
    match (node.start_position(), node.end_position()) {
        (Some(start), Some(end)) => Span {
            line: start.line(),
            column: start.character(),
            end_line: end.line(),
            end_column: end.character(),
        },
        (Some(start), None) => Span {
            line: start.line(),
            column: start.character(),
            end_line: start.line(),
            end_column: start.character(),
        },
        _ => Span::default(),
    }
}

/// Text of a node without comments and whitespace (`Remotes.BuyItem`).
pub fn compact(node: &(impl std::fmt::Display + ?Sized)) -> String {
    let text = node.to_string();
    let mut out = String::new();
    for line in text.lines() {
        // Drop `--` comments (outside of string literals).
        let mut quote: Option<char> = None;
        let mut previous = '\0';
        let mut end = line.len();
        for (i, c) in line.char_indices() {
            match quote {
                Some(q) if c == q && previous != '\\' => quote = None,
                Some(_) => {}
                None if c == '"' || c == '\'' || c == '`' => quote = Some(c),
                None if c == '-' && previous == '-' => {
                    end = i - 1;
                    break;
                }
                None => {}
            }
            previous = c;
        }
        for piece in line[..end].split_whitespace() {
            if !out.is_empty() {
                out.push(' ');
            }
            out.push_str(piece);
        }
    }
    if out.chars().count() > 80 {
        let cut: String = out.chars().take(77).collect();
        out = format!("{cut}...");
    }
    out
}

pub fn token_name(token: &TokenReference) -> String {
    token.token().to_string()
}

/// What kind of entry point a function is analysed as.
#[derive(Clone, Debug)]
pub(crate) enum EntryKind {
    /// `OnServerEvent` / `OnServerInvoke` handler.
    Remote { event: &'static str, remote: String },
    /// `Player.Chatted` handler.
    Chat,
    /// Function matched by a configured source pattern.
    Custom {
        trusted: usize,
        name: String,
        /// `Service.Client` for `function Service.Client:Method()`: `self` is
        /// that table, and `self.Server` is `Service` (Knit).
        self_path: Option<(VarId, Vec<Rc<str>>)>,
    },
    /// Any other callback (event connections, spawned threads): trusted parameters.
    Callback { player_param: bool },
}

pub(crate) struct Pending<'a> {
    funcs: Vec<Func<'a>>,
    kind: EntryKind,
    registration: Loc,
    state: Option<State<'a>>,
    rate_limited: bool,
}

/// Per-handler bookkeeping for luau-shield007.
#[derive(Default)]
pub(crate) struct EntryCtx {
    expensive: Vec<String>,
    rate_limited: bool,
    lock_reads: HashSet<String>,
    lock_writes: HashSet<String>,
    /// Locks keyed by the player (`busy[player]`, a player attribute).
    per_player_writes: HashSet<String>,
    /// The handler waits (`task.wait`, `task.delay`) before releasing locks.
    waits: bool,
}

enum ModuleState<'a> {
    Evaluating,
    Done(Value<'a>),
}

struct RawFinding {
    rule: RuleId,
    loc: Loc,
    message: String,
    flow: Option<Flow>,
    detail: Option<String>,
}

pub struct Analyzer<'a> {
    project: &'a Project,
    config: &'a Config,
    raw: Vec<RawFinding>,
    reported: HashSet<(RuleId, usize, usize, usize)>,
    ls003_sources: HashSet<u32>,
    suppressed: HashSet<(RuleId, usize, usize, usize)>,
    modules: HashMap<usize, ModuleState<'a>>,
    /// Modules each file requires (file -> module files).
    required: HashMap<usize, std::collections::BTreeSet<usize>>,
    statics: HashMap<usize, Rc<HashMap<VarId, Value<'a>>>>,
    summaries: HashMap<(usize, usize), Option<Rc<Summary>>>,
    next_source: u32,
    next_frame: u32,
    stack: Vec<(usize, usize)>,
    /// > 0: findings are not reported (validator summaries).
    quiet: u32,
    /// > 0: evaluating only to learn values for a refinement: no calls are analysed.
    peek: u32,
    /// > 0: evaluating a module for `require`: handler registrations are skipped.
    module_eval: u32,
    entry: Option<EntryCtx>,
    /// Nesting of conditions followed through variables (`local ok = ...`).
    condition_depth: u32,
    /// `T[player]` tests seen while refining the current `if` condition.
    pending_lock_reads: Vec<String>,
    budget: usize,
    pending: Vec<Pending<'a>>,
    analysed_entries: HashSet<(usize, usize, usize, usize)>,
    inlined_callbacks: HashSet<(usize, usize)>,
    warnings: Vec<String>,
}

pub fn var_id(file: usize, token: &TokenReference) -> VarId {
    let offset = token.start_position().map(|p| p.bytes()).unwrap_or(0) as u64;
    ((file as u64) << 32) | offset
}

pub fn global_id(file: usize, name: &str) -> VarId {
    // FNV-1a hash of the name, tagged with the high bit.
    let mut hash: u32 = 0x811c9dc5;
    for b in name.bytes() {
        hash ^= b as u32;
        hash = hash.wrapping_mul(0x01000193);
    }
    (1 << 63) | ((file as u64 & 0x7fff_ffff) << 32) | hash as u64
}

impl<'a> Analyzer<'a> {
    pub fn new(project: &'a Project, config: &'a Config) -> Analyzer<'a> {
        Analyzer {
            project,
            config,
            raw: Vec::new(),
            reported: HashSet::new(),
            ls003_sources: HashSet::new(),
            suppressed: HashSet::new(),
            modules: HashMap::new(),
            required: HashMap::new(),
            statics: HashMap::new(),
            summaries: HashMap::new(),
            next_source: 1,
            next_frame: 1,
            stack: Vec::new(),
            quiet: 0,
            peek: 0,
            module_eval: 0,
            entry: None,
            condition_depth: 0,
            pending_lock_reads: Vec::new(),
            budget: ENTRY_BUDGET,
            pending: Vec::new(),
            analysed_entries: HashSet::new(),
            inlined_callbacks: HashSet::new(),
            warnings: Vec::new(),
        }
    }

    fn loc(&self, file: usize, node: &impl Node) -> Loc {
        Loc {
            file,
            span: span_of(node),
        }
    }

    fn new_frame_id(&mut self) -> u32 {
        self.next_frame += 1;
        self.next_frame
    }

    fn new_source(
        &mut self,
        kind: SourceKind,
        name: String,
        description: String,
        loc: Loc,
        annotation: Option<String>,
    ) -> Rc<Source> {
        self.next_source += 1;
        Rc::new(Source {
            id: self.next_source,
            kind,
            name,
            description,
            loc,
            annotation,
        })
    }

    fn tainted(&mut self, source: Rc<Source>) -> Value<'a> {
        let path: Rc<str> = Rc::from(source.name.as_str());
        Value {
            flows: vec![Flow::new(source)],
            path: Some(path),
            ..Value::default()
        }
    }

    /// Analyses every file of the project.
    pub fn run(mut self) -> AnalysisOutput {
        let project = self.project;
        for file in &project.files {
            let Some(ast) = file.ast.as_ref() else {
                continue;
            };
            if file.context.replicated_to_clients() {
                let place = match (file.kind, file.context) {
                    (ScriptKind::LocalScript, _) => "a LocalScript".to_string(),
                    (_, RunContext::Client) => {
                        "a ModuleScript that replicates to clients".to_string()
                    }
                    _ => "a ModuleScript replicated to clients".to_string(),
                };
                for hit in crate::rules::secrets::find_secrets(file.id, ast) {
                    self.report(
                        RuleId::Ls008,
                        hit.loc,
                        format!(
                            "{} `{}` is hard-coded in {place}: every player can read it",
                            hit.kind, hit.preview
                        ),
                        None,
                        None,
                    );
                }
            }
            if file.context.may_run_on_server() && file.kind != ScriptKind::LocalScript {
                let server = file.context == RunContext::Server;
                for hit in crate::rules::invoke_client::find_invoke_client(file.id, ast, server) {
                    self.report(RuleId::Ls006, hit.loc, hit.message, None, None);
                }
            }
        }
        for file in &project.files {
            if file.ast.is_none() || !file.context.may_run_on_server() {
                continue;
            }
            let id = file.id;
            let outcome = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                self.analyze_file(id);
            }));
            if outcome.is_err() {
                self.warnings.push(format!(
                    "internal error while analysing {}: some findings may be missing (please report this file)",
                    file.rel
                ));
                self.stack.clear();
                self.quiet = 0;
                self.peek = 0;
                self.module_eval = 0;
                self.entry = None;
                self.pending.clear();
            }
        }
        self.finish()
    }

    fn analyze_file(&mut self, file: usize) {
        let Some(ast) = self.project.files[file].ast.as_ref() else {
            return;
        };
        self.budget = ENTRY_BUDGET * 2;
        let mut frame = self.top_frame(file);
        let final_state = self.exec_block(&mut frame, ast.nodes(), State::default());
        let final_state =
            State::join_all(std::iter::once(final_state).chain(frame.return_states.drain(..)));
        self.statics
            .entry(file)
            .or_insert_with(|| Rc::new(final_state.vars.clone()));
        self.drain_pending(&final_state);
    }

    fn top_frame(&mut self, file: usize) -> Frame<'a> {
        let id = self.new_frame_id();
        Frame {
            id,
            file,
            closure: None,
            base_scope: Rc::new(Default::default()),
            scopes: vec![Default::default()],
            returns: None,
            return_states: Vec::new(),
            varargs: Vec::new(),
            vararg_rest: None,
            loops: Vec::new(),
            summary: None,
            name: Rc::from("<script>"),
        }
    }

    fn drain_pending(&mut self, top_state: &State<'a>) {
        let mut guard = 0;
        while !self.pending.is_empty() && guard < 10_000 {
            guard += 1;
            let pending = std::mem::take(&mut self.pending);
            for p in pending {
                let base = p.state.clone().unwrap_or_else(|| top_state.clone());
                self.run_entry(p, base);
            }
        }
    }

    pub(crate) fn register_entry(
        &mut self,
        funcs: Vec<Func<'a>>,
        kind: EntryKind,
        registration: Loc,
        state: &State<'a>,
        rate_limited: bool,
        top_level: bool,
    ) {
        if self.peek > 0 || self.quiet > 0 || self.module_eval > 0 || funcs.is_empty() {
            return;
        }
        self.pending.push(Pending {
            funcs,
            kind,
            registration,
            state: if top_level { None } else { Some(state.clone()) },
            rate_limited,
        });
    }

    fn param_annotation(body: &FunctionBody, index: usize) -> Option<String> {
        body.type_specifiers()
            .nth(index)
            .flatten()
            .map(|t| compact(t.type_info()))
    }

    fn run_entry(&mut self, pending: Pending<'a>, base: State<'a>) {
        for func in &pending.funcs {
            let Func::Closure(closure) = func else {
                continue;
            };
            let (kf, kb) = closure.key();
            let kind_tag = match &pending.kind {
                EntryKind::Remote { .. } => 1,
                EntryKind::Chat => 2,
                EntryKind::Custom { .. } => 3,
                EntryKind::Callback { .. } => 4,
            };
            let reg_key = if kind_tag == 4 {
                0
            } else {
                pending.registration.span.line * 10_000 + pending.registration.file
            };
            if !self.analysed_entries.insert((kf, kb, kind_tag, reg_key)) {
                continue;
            }
            let args = self.entry_args(closure, &pending.kind, &base);
            let is_remote = matches!(pending.kind, EntryKind::Remote { .. });
            if is_remote {
                self.entry = Some(EntryCtx {
                    rate_limited: pending.rate_limited,
                    ..EntryCtx::default()
                });
            }
            self.budget = ENTRY_BUDGET;
            let mut state = base.clone();
            let (args, rest) = args;
            self.call_closure(
                &mut state,
                closure.clone(),
                args,
                rest,
                pending.registration,
                true,
            );
            if is_remote {
                let ctx = self.entry.take().unwrap_or_default();
                // A per-player lock always limits the player; a global flag
                // (`debounce`, `tool.Enabled`) only when the handler waits
                // before releasing it.
                let locked = ctx.lock_reads.iter().any(|t| {
                    ctx.per_player_writes.contains(t) || (ctx.waits && ctx.lock_writes.contains(t))
                });
                if !ctx.expensive.is_empty() && !ctx.rate_limited && !locked {
                    let EntryKind::Remote { event, remote } = &pending.kind else {
                        unreachable!()
                    };
                    let mut ops: Vec<String> = Vec::new();
                    for op in ctx.expensive {
                        if !ops.contains(&op) {
                            ops.push(op);
                        }
                    }
                    let shown: Vec<&str> = ops.iter().take(3).map(String::as_str).collect();
                    let more = if ops.len() > 3 {
                        format!(" and {} more", ops.len() - 3)
                    } else {
                        String::new()
                    };
                    self.report(
                        RuleId::Ls007,
                        pending.registration,
                        format!(
                            "the `{remote}.{event}` handler calls {}{more} on every request, with no rate limit",
                            shown.join(", ")
                        ),
                        None,
                        None,
                    );
                }
            }
        }
    }

    /// Arguments an entry point is called with: trusted player(s) and
    /// untrusted values.
    fn entry_args(
        &mut self,
        closure: &Rc<Closure<'a>>,
        kind: &EntryKind,
        base: &State<'a>,
    ) -> (Vec<Value<'a>>, Option<Value<'a>>) {
        let body = closure.body;
        let file = closure.file;
        let mut args = Vec::new();
        let mut rest = None;
        let trusted = match kind {
            EntryKind::Remote { .. } => 1,
            EntryKind::Chat => 0,
            EntryKind::Custom { trusted, .. } => *trusted,
            EntryKind::Callback { .. } => usize::MAX,
        };
        // A method declared with `:` receives `self` implicitly: it is not a
        // value chosen by the client.
        if closure.is_method {
            let mut self_value = Value::unknown().with_path("self");
            if let EntryKind::Custom {
                self_path: Some((root, keys)),
                ..
            } = kind
            {
                let service = base.vars.get(root).cloned().or_else(|| {
                    self.statics
                        .get(&closure.file)
                        .and_then(|s| s.get(root))
                        .cloned()
                });
                if let Some(service) = service {
                    let mut client = service.clone();
                    for key in keys {
                        client = match &client.kind {
                            Kind::Table(t) => t.fields.get(key).cloned().unwrap_or_default(),
                            _ => Value::unknown(),
                        };
                    }
                    let mut table = match &client.kind {
                        Kind::Table(t) => (**t).clone(),
                        _ => value::Table::default(),
                    };
                    table.fields.insert(Rc::from("Server"), service);
                    self_value = Value::of(Kind::Table(Rc::new(table))).with_path("self");
                }
            }
            args.push(self_value);
        }
        let player = |name: &str| {
            let mut v = Value::obj(ObjClass::Player, None, name);
            v.player_rel = true;
            v
        };
        for (position, param) in body.parameters().iter().enumerate() {
            match param {
                Parameter::Name(token) => {
                    let name = token_name(token);
                    if position < trusted {
                        let player_like = match kind {
                            EntryKind::Callback { player_param } => *player_param && position == 0,
                            _ => true,
                        };
                        args.push(if player_like {
                            player(&name)
                        } else {
                            Value::unknown().with_path(name.as_str())
                        });
                        continue;
                    }
                    let description = match kind {
                        EntryKind::Remote { event, remote } => format!(
                            "`{name}` (parameter #{}) of the `{remote}.{event}` handler is sent by the client",
                            position + 1
                        ),
                        EntryKind::Chat => {
                            format!("`{name}` is the chat message typed by the player")
                        }
                        EntryKind::Custom { name: fname, .. } => format!(
                            "`{name}` (parameter #{}) of `{fname}` is sent by the client",
                            position + 1
                        ),
                        EntryKind::Callback { .. } => {
                            unreachable!("callbacks trust every parameter")
                        }
                    };
                    let source_kind = match kind {
                        EntryKind::Chat => SourceKind::ChatMessage,
                        EntryKind::Custom { .. } => SourceKind::Custom,
                        _ => SourceKind::RemoteParameter,
                    };
                    let loc = self.loc(file, token);
                    let annotation = Self::param_annotation(body, position);
                    let source = self.new_source(source_kind, name, description, loc, annotation);
                    let value = self.tainted(source);
                    args.push(value);
                }
                Parameter::Ellipsis(token) if trusted != usize::MAX => {
                    // `function(...)`: the first values are still trusted.
                    for _ in position..trusted {
                        args.push(player("player"));
                    }
                    let loc = self.loc(file, token);
                    let description = match kind {
                        EntryKind::Remote { event, remote } => {
                            format!("`...` of the `{remote}.{event}` handler is sent by the client")
                        }
                        _ => "`...` is sent by the client".to_string(),
                    };
                    let source = self.new_source(
                        SourceKind::RemoteParameter,
                        "...".into(),
                        description,
                        loc,
                        None,
                    );
                    rest = Some(self.tainted(source));
                }
                _ => {}
            }
        }
        (args, rest)
    }

    /// Records a finding (deduplicated, honouring configuration and suppressions).
    pub(crate) fn report(
        &mut self,
        rule: RuleId,
        loc: Loc,
        message: String,
        flow: Option<&Flow>,
        detail: Option<String>,
    ) {
        if self.quiet > 0 || self.peek > 0 || !self.config.rule_enabled(rule) {
            return;
        }
        if flow.is_some_and(|f| f.source.kind == SourceKind::Probe) {
            return;
        }
        let key = (rule, loc.file, loc.span.line, loc.span.column);
        if rule == RuleId::Ls003 {
            if let Some(flow) = flow {
                if !self.ls003_sources.insert(flow.source.id) {
                    return;
                }
            }
        }
        if self.reported.contains(&key) || self.suppressed.contains(&key) {
            return;
        }
        let file = &self.project.files[loc.file];
        if file.suppressions.is_suppressed(rule, loc.span.line) {
            self.suppressed.insert(key);
            return;
        }
        self.reported.insert(key);
        self.raw.push(RawFinding {
            rule,
            loc,
            message,
            flow: flow.cloned(),
            detail,
        });
    }

    fn finish(self) -> AnalysisOutput {
        let mut findings = Vec::new();
        for raw in &self.raw {
            findings.push(self.to_finding(raw));
        }
        AnalysisOutput {
            findings,
            suppressed: self.suppressed.len(),
            warnings: self.warnings,
        }
    }

    fn step(&self, loc: Loc, note: String) -> FlowStep {
        FlowStep {
            file: self.project.files[loc.file].rel.clone(),
            line: loc.span.line,
            column: loc.span.column,
            note,
        }
    }

    fn to_finding(&self, raw: &RawFinding) -> Finding {
        let meta = raw.rule.meta();
        let mut flow_steps = Vec::new();
        let mut why = meta.why.to_string();
        if let Some(flow) = &raw.flow {
            let source = &flow.source;
            let mut note = source.description.clone();
            if let Some(annotation) = &source.annotation {
                note.push_str(&format!(
                    " (the type annotation `{annotation}` is not checked at runtime)"
                ));
            }
            flow_steps.push(self.step(source.loc, note));
            for (loc, note) in flow.step_list() {
                flow_steps.push(self.step(loc, note.to_string()));
            }
            if source.annotation.is_some() {
                why.push_str(
                    " Luau type annotations are erased at runtime: they do not validate anything.",
                );
            }
        }
        flow_steps.push(self.step(raw.loc, raw.message.clone()));
        let fix = match &raw.detail {
            Some(detail) => format!("{detail} {}", meta.fix),
            None => meta.fix.to_string(),
        };
        Finding {
            rule: raw.rule,
            severity: self.config.severity_of(raw.rule),
            title: meta.title.to_string(),
            file: self.project.files[raw.loc.file].rel.clone(),
            span: raw.loc.span,
            message: raw.message.clone(),
            snippet: String::new(),
            flow: flow_steps,
            why,
            fix,
            ai_explanation: None,
            file_id: raw.loc.file,
        }
    }
}

/// Runs the taint analysis on a loaded project.
pub fn analyze(project: &Project, config: &Config) -> AnalysisOutput {
    Analyzer::new(project, config).run()
}
