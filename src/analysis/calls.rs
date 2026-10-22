//! Function and method calls: interprocedural analysis of closures, models of
//! the standard library and of the Roblox API, `require`, and sinks.

use super::interp::{Key, number_literal, unwrap_expr};
use super::state::{Frame, State, Summary, SummaryCollector};
use super::value::{
    Builtin, Checks, Closure, Flow, Func, Kind, ObjClass, SourceKind, Table, Target, Validator,
    Value, check,
};
use super::{Analyzer, EntryKind, ModuleState, compact, token_name, var_id};
use crate::finding::Loc;
use crate::project::ScriptKind;
use crate::rules::sinks::{self, SinkKind};
use crate::rules::{RuleId, is_data_container_name, is_stat_name};
use full_moon::ast::{Expression, Parameter};
use std::collections::BTreeMap;
use std::rc::Rc;

const RATE_LIMIT_WORDS: &[&str] = &[
    "ratelimit",
    "rate_limit",
    "throttle",
    "cooldown",
    "debounce",
    "limiter",
];

const VALIDATOR_PREFIXES: &[&str] = &[
    "is", "validate", "verify", "check", "sanitize", "assert", "ensure", "valid",
];

/// Does `name` look like a validation function (`isValidItem`, `validateAmount`)?
pub(crate) fn looks_like_validator(name: &str) -> bool {
    let lower = name.to_ascii_lowercase();
    VALIDATOR_PREFIXES.iter().any(|prefix| {
        lower.starts_with(prefix)
            && name[prefix.len()..]
                .chars()
                .next()
                .is_none_or(|c| c.is_ascii_uppercase() || c == '_')
    }) || lower.starts_with("valid")
}

/// Does `name` look like an asserting validator (`assertAmount`, `ensureOwner`)?
fn looks_like_assertion(name: &str) -> bool {
    let lower = name.to_ascii_lowercase();
    ["assert", "ensure", "validate", "verify"]
        .iter()
        .any(|p| lower.starts_with(p))
}

pub(crate) fn has_rate_limit_word(text: &str) -> bool {
    let lower = text.to_ascii_lowercase();
    RATE_LIMIT_WORDS.iter().any(|w| lower.contains(w))
}

/// The `t` library member `name`.
pub(crate) fn t_member(name: &str) -> Validator {
    let checks = match name {
        "number" => check::TYPE_NUMBER | check::NAN_SAFE,
        "string" => check::TYPE_STRING,
        "boolean" => check::TYPE_BOOLEAN,
        "table" => check::TYPE_TABLE,
        "Instance" => check::TYPE_INSTANCE,
        // t.number and t.integer reject NaN (`t.nan` accepts it).
        "integer" => check::TYPE_NUMBER | check::NAN_SAFE,
        "numberPositive" => check::TYPE_NUMBER | check::LOWER | check::NAN_SAFE,
        "numberNegative" => check::TYPE_NUMBER | check::UPPER | check::NAN_SAFE,
        "nan" | "any" | "none" | "nil" | "optional" => 0,
        "numberMin"
        | "numberMinExclusive"
        | "numberMax"
        | "numberMaxExclusive"
        | "numberConstrained"
        | "numberConstrainedExclusive"
        | "literal"
        | "keyOf"
        | "valueOf"
        | "enum"
        | "instanceOf"
        | "instanceIsA"
        | "tuple"
        | "strict"
        | "interface"
        | "strictInterface"
        | "array"
        | "strictArray"
        | "map"
        | "keys"
        | "values"
        | "union"
        | "intersection"
        | "children"
        | "match"
        | "wrap"
        | "unionList"
        | "intersectionList"
        | "exactly" => {
            return Validator {
                constructor: Some(Rc::from(name)),
                ..Validator::default()
            };
        }
        _ => check::TYPE_OTHER,
    };
    Validator {
        checks,
        ..Validator::default()
    }
}

fn validator_from(value: &Value<'_>) -> Validator {
    match &value.kind {
        Kind::Validator(v) if v.constructor.is_none() => (**v).clone(),
        _ => Validator::default(),
    }
}

/// Builds the checker returned by `t.<constructor>(args)`.
fn t_construct(name: &str, args: &[Value<'_>]) -> Validator {
    let checks = match name {
        "numberMin" | "numberMinExclusive" => check::TYPE_NUMBER | check::LOWER | check::NAN_SAFE,
        "numberMax" | "numberMaxExclusive" => check::TYPE_NUMBER | check::UPPER | check::NAN_SAFE,
        "numberConstrained" | "numberConstrainedExclusive" => {
            check::TYPE_NUMBER | check::BOUNDS | check::NAN_SAFE
        }
        "literal" | "keyOf" | "valueOf" | "enum" | "exactly" => check::ALLOWLIST,
        "instanceOf" | "instanceIsA" | "children" => check::TYPE_INSTANCE,
        "match" => check::TYPE_STRING | check::PATTERN,
        "array" | "strictArray" | "map" | "keys" | "values" => check::TYPE_TABLE,
        "strict" | "wrap" => {
            let mut inner = args.first().map(validator_from).unwrap_or_default();
            inner.asserting = true;
            return inner;
        }
        "optional" => return args.first().map(validator_from).unwrap_or_default(),
        "tuple" => {
            return Validator {
                positional: args.iter().map(|a| validator_from(a).checks).collect(),
                ..Validator::default()
            };
        }
        "union" | "unionList" => args
            .iter()
            .map(|a| validator_from(a).checks)
            .reduce(|a, b| a & b)
            .unwrap_or(0),
        "intersection" | "intersectionList" => args
            .iter()
            .map(|a| validator_from(a).checks)
            .fold(0, |a, b| a | b),
        "interface" | "strictInterface" => {
            let fields = match args.first().map(|a| &a.kind) {
                Some(Kind::Table(table)) => table
                    .fields
                    .iter()
                    .map(|(k, v)| (k.clone(), validator_from(v).checks))
                    .collect(),
                _ => Vec::new(),
            };
            return Validator {
                checks: check::TYPE_TABLE,
                fields,
                ..Validator::default()
            };
        }
        _ => 0,
    };
    Validator {
        checks,
        ..Validator::default()
    }
}

/// Splits a display path into names (`player.leaderstats.Coins` -> 3 names).
fn path_names(path: &str) -> Vec<&str> {
    path.split(|c: char| !(c.is_alphanumeric() || c == '_'))
        .filter(|s| !s.is_empty())
        .collect()
}

fn path_has_stat(path: &str) -> bool {
    path_names(path)
        .iter()
        .any(|n| *n == "leaderstats" || is_stat_name(n))
}

/// `data.Inventory` for the target `data.Inventory[itemId]`.
fn syntactic_base(target: &str) -> &str {
    if target.ends_with(']') {
        let mut depth = 0;
        for (i, c) in target.char_indices().rev() {
            match c {
                ']' => depth += 1,
                '[' => {
                    depth -= 1;
                    if depth == 0 {
                        return &target[..i];
                    }
                }
                _ => {}
            }
        }
        return target;
    }
    match target.rfind(['.', ':']) {
        Some(i) => &target[..i],
        None => target,
    }
}

fn path_has_data(path: &str) -> bool {
    path_names(path).iter().any(|n| is_data_container_name(n))
}

impl<'a> Analyzer<'a> {
    // ------------------------------------------------------------------
    // luau-shield007 bookkeeping
    // ------------------------------------------------------------------

    fn note_expensive(&mut self, what: String) {
        if self.peek > 0 {
            return;
        }
        if let Some(entry) = self.entry.as_mut() {
            entry.expensive.push(what);
        }
    }

    fn note_rate_limit(&mut self) {
        if self.peek > 0 {
            return;
        }
        if let Some(entry) = self.entry.as_mut() {
            entry.rate_limited = true;
        }
    }

    fn note_rate_limit_name(&mut self, display: &str) {
        if has_rate_limit_word(display) {
            self.note_rate_limit();
        }
    }

    // ------------------------------------------------------------------
    // Sinks
    // ------------------------------------------------------------------

    /// Reports the first flow of `value` that is not checked enough for `kind`.
    pub(crate) fn check_value(
        &mut self,
        rule: RuleId,
        kind: SinkKind,
        value: &Value<'a>,
        loc: Loc,
        what: &str,
    ) {
        if self.peek > 0 || self.quiet > 0 {
            return;
        }
        for flow in value.deep_flows() {
            let economy_like = matches!(
                kind,
                SinkKind::Economy
                    | SinkKind::DataKey
                    | SinkKind::Property
                    | SinkKind::Text
                    | SinkKind::InstanceProperty
            );
            if flow.instance_data && economy_like {
                if let Some(missing) = sinks::missing(SinkKind::InstanceUse, &flow) {
                    self.report(
                        RuleId::Ls003,
                        loc,
                        format!(
                            "data read from `{}`, an Instance chosen by the client, {what}",
                            flow.source.name
                        ),
                        Some(&flow),
                        Some(missing),
                    );
                    return;
                }
                continue;
            }
            let check_kind = if flow.instance_data {
                SinkKind::InstanceUse
            } else {
                kind
            };
            if let Some(missing) = sinks::missing(check_kind, &flow) {
                let subject = match value.path.as_deref() {
                    Some(path)
                        if path != flow.source.name && path.len() <= 60 && !path.contains('(') =>
                    {
                        format!("`{path}` (client-controlled, from `{}`)", flow.source.name)
                    }
                    _ => format!("`{}` (client-controlled)", flow.source.name),
                };
                self.report(
                    rule,
                    loc,
                    format!("{subject} {what}"),
                    Some(&flow),
                    Some(missing),
                );
                return;
            }
        }
    }

    /// luau-shield003: the client chose this Instance, and we are about to use it.
    fn check_instance_use(&mut self, value: &Value<'a>, loc: Loc, what: &str) {
        if self.peek > 0 || self.quiet > 0 {
            return;
        }
        for flow in &value.flows {
            if !flow.raw
                || flow.any(
                    check::TYPE_STRING
                        | check::TYPE_NUMBER
                        | check::TYPE_BOOLEAN
                        | check::TYPE_TABLE,
                )
            {
                continue;
            }
            if let Some(missing) = sinks::missing(SinkKind::InstanceUse, flow) {
                self.report(
                    RuleId::Ls003,
                    loc,
                    format!(
                        "{what} on `{}`, an Instance chosen by the client",
                        flow.source.name
                    ),
                    Some(flow),
                    Some(missing),
                );
                return;
            }
        }
    }

    #[allow(clippy::too_many_arguments)]
    pub(crate) fn check_assignment_sinks(
        &mut self,
        frame: &Frame<'a>,
        _state: &State<'a>,
        base: &Value<'a>,
        key: &Key<'a>,
        shown: &Value<'a>,
        _full: &Value<'a>,
        loc: Loc,
        target: &str,
        verb: &str,
    ) {
        let name = key.name();
        if let Some(n) = name {
            if n.chars().next().is_some_and(|c| c.is_ascii_uppercase()) {
                self.check_instance_use(base, loc, &format!("`{target}` is set"));
            }
        }
        let fresh = matches!(&base.kind, Kind::Table(t) if t.fresh_frame == Some(frame.id));
        let client_table = base.flows.iter().any(|f| f.raw);
        // The container is named by the value's path (`player.leaderstats.Coins`)
        // and by the code itself (`profile` in `profile[key] = value`).
        let names = format!(
            "{} {}",
            base.path.as_deref().unwrap_or(""),
            syntactic_base(target)
        );
        let what = format!("is {verb} `{target}`");
        if !fresh && !client_table {
            match (name, key) {
                (Some("Value"), _) if path_has_stat(&names) => {
                    self.check_value(RuleId::Ls001, SinkKind::Economy, shown, loc, &what);
                }
                (Some(n), _) if is_stat_name(n) && sinks::property_sink(n).is_none() => {
                    self.check_value(RuleId::Ls001, SinkKind::Economy, shown, loc, &what);
                }
                (None, Key::Dynamic(key_value, _))
                    if path_has_data(&names) || path_has_stat(&names) =>
                {
                    let container = syntactic_base(target).to_string();
                    self.check_value(
                        RuleId::Ls001,
                        SinkKind::DataKey,
                        key_value,
                        loc,
                        &format!("chooses which entry of `{container}` is written"),
                    );
                    self.check_value(RuleId::Ls001, SinkKind::Economy, shown, loc, &what);
                }
                (Some(_), _) if path_has_data(&names) && !matches!(base.kind, Kind::Obj(_)) => {
                    self.check_value(RuleId::Ls001, SinkKind::Economy, shown, loc, &what);
                }
                _ => {}
            }
        }
        if let Some(n) = name {
            if let Some(kind) = sinks::property_sink(n) {
                if !matches!(base.kind, Kind::Table(_)) {
                    self.check_value(RuleId::Ls002, kind, shown, loc, &what);
                }
            }
        }
    }

    #[allow(clippy::too_many_arguments)]
    fn check_method_sinks(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        recv: &Value<'a>,
        name: &str,
        args: &[Value<'a>],
        recv_display: &str,
        loc: Loc,
    ) {
        let call = format!("{recv_display}:{name}()");
        if !sinks::is_query_method(name) && !sinks::is_string_method(name) {
            self.check_instance_use(recv, loc, &format!("`{call}` is called"));
        }
        if (recv.is_service("Debris") && name == "AddItem")
            || (recv.is_service("CollectionService") && matches!(name, "AddTag" | "RemoveTag"))
        {
            if let Some(arg) = args.first() {
                self.check_instance_use(arg, loc, &format!("`{call}` is called"));
            }
        }
        // luau-shield001: DataStores and MemoryStores.
        let store_like = matches!(
            recv.class(),
            Some(ObjClass::DataStore | ObjClass::MemoryStore)
        ) || recv_display.contains("Store")
            || recv_display.contains("store");
        if store_like
            && matches!(
                name,
                "SetAsync" | "UpdateAsync" | "IncrementAsync" | "RemoveAsync" | "AddAsync"
            )
        {
            for (i, arg) in args.iter().enumerate() {
                if matches!(arg.kind, Kind::Func(_)) && name == "UpdateAsync" {
                    // The value saved is what the transform function returns.
                    let funcs = arg.funcs();
                    for func in funcs {
                        if let Func::Closure(closure) = func {
                            let mut s = state.clone();
                            let returned = self.call_closure(
                                &mut s,
                                closure,
                                vec![Value::unknown()],
                                None,
                                loc,
                                false,
                            );
                            if let Some(first) = returned.first() {
                                self.check_value(
                                    RuleId::Ls001,
                                    SinkKind::Economy,
                                    first,
                                    loc,
                                    &format!("is saved by `{call}`"),
                                );
                            }
                        }
                    }
                    continue;
                }
                if i == 0 && name != "AddAsync" {
                    let what = format!("is used as the key of `{call}`");
                    self.check_value(RuleId::Ls001, SinkKind::DataKey, arg, loc, &what);
                } else {
                    let what = format!("is written by `{call}`");
                    self.check_value(RuleId::Ls001, SinkKind::Economy, arg, loc, &what);
                }
            }
        }
        if name == "SetAttribute" {
            let attr = args.first();
            let value = args.get(1);
            if let (Some(attr), Some(value)) = (attr, value) {
                let what = format!("is written by `{call}`");
                match attr.str_const() {
                    Some(n) if is_stat_name(n) => {
                        self.check_value(RuleId::Ls001, SinkKind::Economy, value, loc, &what);
                    }
                    _ => {
                        self.check_value(RuleId::Ls002, SinkKind::Property, value, loc, &what);
                        self.check_value(
                            RuleId::Ls002,
                            SinkKind::Property,
                            attr,
                            loc,
                            &format!("chooses the attribute written by `{call}`"),
                        );
                    }
                }
            }
        }
        if sinks::method_sink(name) {
            if let Some(arg) = args.first() {
                self.check_value(
                    RuleId::Ls002,
                    SinkKind::Property,
                    arg,
                    loc,
                    &format!("is passed to `{call}`"),
                );
            }
        }
        // luau-shield005: HttpService.
        if recv.is_service("HttpService") {
            let url_what = format!("is used in the URL of `{call}`");
            let body_what = format!("is sent in the body of `{call}`");
            let header_what = format!("is sent in the headers of `{call}`");
            match name {
                "GetAsync" => {
                    if let Some(url) = args.first() {
                        self.check_value(RuleId::Ls005, SinkKind::HttpUrl, url, loc, &url_what);
                    }
                    if let Some(headers) = args.get(2) {
                        self.check_value(
                            RuleId::Ls005,
                            SinkKind::HttpBody,
                            headers,
                            loc,
                            &header_what,
                        );
                    }
                }
                "PostAsync" => {
                    if let Some(url) = args.first() {
                        self.check_value(RuleId::Ls005, SinkKind::HttpUrl, url, loc, &url_what);
                    }
                    if let Some(body) = args.get(1) {
                        self.check_value(RuleId::Ls005, SinkKind::HttpBody, body, loc, &body_what);
                    }
                    if let Some(headers) = args.get(4) {
                        self.check_value(
                            RuleId::Ls005,
                            SinkKind::HttpBody,
                            headers,
                            loc,
                            &header_what,
                        );
                    }
                }
                "RequestAsync" => {
                    if let Some(options) = args.first() {
                        match &options.kind {
                            Kind::Table(table) => {
                                for (field, value) in &table.fields {
                                    let (kind, what) = match &**field {
                                        "Url" | "Method" => (SinkKind::HttpUrl, &url_what),
                                        "Headers" => (SinkKind::HttpBody, &header_what),
                                        _ => (SinkKind::HttpBody, &body_what),
                                    };
                                    self.check_value(RuleId::Ls005, kind, value, loc, what);
                                }
                                if let Some(dynamic) = &table.dynamic {
                                    self.check_value(
                                        RuleId::Ls005,
                                        SinkKind::HttpBody,
                                        dynamic,
                                        loc,
                                        &body_what,
                                    );
                                }
                                self.check_value(
                                    RuleId::Ls005,
                                    SinkKind::HttpUrl,
                                    &Value {
                                        kind: Kind::Unknown,
                                        ..options.clone()
                                    },
                                    loc,
                                    &url_what,
                                );
                            }
                            _ => self.check_value(
                                RuleId::Ls005,
                                SinkKind::HttpUrl,
                                options,
                                loc,
                                &url_what,
                            ),
                        }
                    }
                }
                _ => {}
            }
        }
        let _ = frame;
    }

    fn check_custom_sinks(&mut self, path: &[String], args: &[Value<'a>], loc: Loc, display: &str) {
        let matching: Vec<_> = self
            .config
            .sinks
            .iter()
            .filter(|s| s.pattern.matches(path))
            .cloned()
            .collect();
        for sink in matching {
            let kind = match sink.rule {
                RuleId::Ls001 => SinkKind::Economy,
                RuleId::Ls002 => SinkKind::Property,
                RuleId::Ls003 => SinkKind::InstanceUse,
                RuleId::Ls005 => SinkKind::HttpUrl,
                _ => SinkKind::Code,
            };
            for (i, arg) in args.iter().enumerate() {
                if sink
                    .arguments
                    .as_ref()
                    .is_some_and(|a| !a.contains(&(i + 1)))
                {
                    continue;
                }
                if kind == SinkKind::InstanceUse {
                    self.check_instance_use(
                        arg,
                        loc,
                        &format!("`{display}()` (configured sink) is called"),
                    );
                } else {
                    self.check_value(
                        sink.rule,
                        kind,
                        arg,
                        loc,
                        &format!(
                            "is passed to `{display}` (argument #{}, configured sink)",
                            i + 1
                        ),
                    );
                }
            }
        }
    }

    fn sanitizer_checks(&self, path: &[String]) -> Option<Checks> {
        self.config
            .sanitizers
            .iter()
            .filter(|s| s.pattern.matches(path))
            .map(|s| s.checks)
            .reduce(|a, b| a | b)
    }

    // ------------------------------------------------------------------
    // Calls
    // ------------------------------------------------------------------

    /// Facts from a validator call applied to the targets of its arguments.
    pub(crate) fn validator_facts(
        &self,
        frame: &Frame<'a>,
        validator: &Validator,
        arg_exprs: &[&'a Expression],
    ) -> super::state::Facts {
        let mut facts = super::state::Facts::default();
        if !validator.positional.is_empty() {
            for (i, checks) in validator.positional.iter().enumerate() {
                if let Some(target) = arg_exprs.get(i).and_then(|e| self.target_of(frame, e)) {
                    facts.add(target, *checks);
                }
            }
        } else if let Some(target) = arg_exprs.first().and_then(|e| self.target_of(frame, e)) {
            facts.add(target.clone(), validator.checks);
            if let Target::Var(id) = target {
                for (field, checks) in &validator.fields {
                    facts.add(Target::Path(id, field.clone()), *checks);
                }
            }
        }
        facts
    }

    #[allow(clippy::too_many_arguments)]
    pub(crate) fn call_value(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        callee: &Value<'a>,
        args: Vec<Value<'a>>,
        arg_exprs: &[&'a Expression],
        callee_path: Option<&[String]>,
        display: &str,
        loc: Loc,
        statement: bool,
    ) -> Vec<Value<'a>> {
        self.note_rate_limit_name(display);
        if let Some(path) = callee_path {
            self.check_custom_sinks(path, &args, loc, display);
            if let Some(checks) = self.sanitizer_checks(path) {
                for expr in arg_exprs {
                    if let Some(target) = self.target_of(frame, expr) {
                        state.add_checks(&target, checks);
                    }
                }
                let mut result = args.into_iter().next().unwrap_or_default();
                result.add_checks(checks);
                return vec![result];
            }
        }
        if callee.is_tainted() {
            self.check_value(
                RuleId::Ls004,
                SinkKind::Code,
                callee,
                loc,
                &format!("chooses the function called by `{display}(...)`"),
            );
        }
        match &callee.kind {
            Kind::Func(funcs) => {
                let funcs: Vec<Func<'a>> = funcs.iter().cloned().collect();
                if funcs.len() == 1 {
                    return self.call_func(
                        frame, state, &funcs[0], args, arg_exprs, loc, statement, display,
                    );
                }
                let mut results: Option<Vec<Value<'a>>> = None;
                let mut states = Vec::new();
                for func in funcs {
                    let mut s = state.clone();
                    let r = self.call_func(
                        frame,
                        &mut s,
                        &func,
                        args.clone(),
                        arg_exprs,
                        loc,
                        statement,
                        display,
                    );
                    states.push(s);
                    results = Some(match results {
                        None => r,
                        Some(prev) => join_lists(&prev, &r),
                    });
                }
                *state = State::join_all(states);
                results.unwrap_or_else(|| vec![Value::nil()])
            }
            Kind::Validator(validator) => {
                if let Some(constructor) = &validator.constructor {
                    return vec![Value::of(Kind::Validator(Rc::new(t_construct(
                        constructor,
                        &args,
                    ))))];
                }
                if statement && validator.asserting {
                    let facts = self.validator_facts(frame, validator, arg_exprs);
                    self.apply_facts(state, &facts);
                }
                vec![Value::of(Kind::Bool(None))]
            }
            _ => self.call_unknown(
                frame,
                state,
                args,
                arg_exprs,
                callee_path,
                display,
                loc,
                statement,
            ),
        }
    }

    #[allow(clippy::too_many_arguments)]
    fn call_func(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        func: &Func<'a>,
        args: Vec<Value<'a>>,
        arg_exprs: &[&'a Expression],
        loc: Loc,
        statement: bool,
        display: &str,
    ) -> Vec<Value<'a>> {
        match func {
            Func::Closure(closure) => {
                self.note_rate_limit_name(&closure.name);
                let tainted_targets: Vec<(usize, Target)> = arg_exprs
                    .iter()
                    .enumerate()
                    .filter(|(i, _)| args.get(*i).is_some_and(|a| a.is_tainted()))
                    .filter_map(|(i, e)| self.target_of(frame, e).map(|t| (i, t)))
                    .collect();
                let result = self.call_closure(state, closure.clone(), args, None, loc, false);
                // Facts the callee guarantees about its arguments when it returns.
                if !tainted_targets.is_empty() && !state.dead {
                    if let Some(summary) = self.summary_of(closure, state) {
                        let offset = usize::from(closure.is_method);
                        for (i, target) in tainted_targets {
                            if let Some(checks) = summary.exit.get(i + offset) {
                                state.add_checks(&target, *checks);
                            }
                        }
                    }
                }
                result
            }
            Func::Builtin(builtin) => self.call_builtin(
                frame, state, *builtin, args, arg_exprs, loc, statement, display,
            ),
        }
    }

    #[allow(clippy::too_many_arguments)]
    fn call_unknown(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        args: Vec<Value<'a>>,
        arg_exprs: &[&'a Expression],
        callee_path: Option<&[String]>,
        display: &str,
        loc: Loc,
        statement: bool,
    ) -> Vec<Value<'a>> {
        let last_name = callee_path
            .and_then(|p| p.last().cloned())
            .unwrap_or_else(|| display.rsplit(['.', ':']).next().unwrap_or("").to_string());
        if statement && self.config.trust_unresolved_validators && looks_like_assertion(&last_name)
        {
            for (i, expr) in arg_exprs.iter().enumerate() {
                if args.get(i).is_some_and(|a| a.is_tainted()) {
                    if let Some(target) = self.target_of(frame, expr) {
                        state.add_checks(&target, check::VALIDATED);
                    }
                }
            }
        }
        // Callbacks passed to unknown functions may run: analyse them once
        // with unknown arguments so that sinks using captured values are seen.
        let mut funcs = Vec::new();
        for arg in &args {
            for func in arg.funcs() {
                if let Func::Closure(closure) = &func {
                    if self.peek == 0 && self.inlined_callbacks.insert(closure.key()) {
                        let mut s = state.clone();
                        let _ = self.call_closure(
                            &mut s,
                            closure.clone(),
                            Vec::new(),
                            None,
                            loc,
                            false,
                        );
                    }
                }
                funcs.push(func);
            }
        }
        let mut result = Value::unknown();
        for arg in &args {
            result.add_flows(arg.derived().flows);
        }
        if !funcs.is_empty() {
            result.kind = Kind::Func(Rc::new(funcs));
        }
        result.path = Some(Rc::from(format!("{display}(...)").as_str()));
        vec![result]
    }

    /// Calls a closure: binds the arguments, interprets the body and returns
    /// the joined return values. `state` becomes the state after the call.
    pub(crate) fn call_closure(
        &mut self,
        state: &mut State<'a>,
        closure: Rc<Closure<'a>>,
        args: Vec<Value<'a>>,
        rest: Option<Value<'a>>,
        loc: Loc,
        entry: bool,
    ) -> Vec<Value<'a>> {
        self.call_closure_with(state, closure, args, rest, loc, entry, None)
            .0
    }

    #[allow(clippy::too_many_arguments)]
    fn call_closure_with(
        &mut self,
        state: &mut State<'a>,
        closure: Rc<Closure<'a>>,
        args: Vec<Value<'a>>,
        rest: Option<Value<'a>>,
        loc: Loc,
        entry: bool,
        summary: Option<SummaryCollector>,
    ) -> (Vec<Value<'a>>, Option<SummaryCollector>) {
        let key = closure.key();
        if self.peek > 0
            || self.budget == 0
            || self.stack.len() >= self.config.max_call_depth
            || self.stack.contains(&key)
        {
            let mut v = Value::unknown();
            for a in args.iter().chain(rest.iter()) {
                v.add_flows(a.derived().flows);
            }
            return (vec![v], None);
        }
        self.stack.push(key);
        let id = self.new_frame_id();
        let mut frame = Frame {
            id,
            file: closure.file,
            closure: Some(closure.clone()),
            base_scope: closure.captured.clone(),
            scopes: vec![BTreeMap::new()],
            returns: None,
            return_states: Vec::new(),
            varargs: Vec::new(),
            vararg_rest: rest,
            loops: Vec::new(),
            summary,
            name: closure.name.clone(),
        };
        let mut inner = std::mem::take(state);
        let mut args = args.into_iter();
        if closure.is_method {
            let self_value = args.next().unwrap_or_default();
            let token = closure.body.parameters_parentheses().tokens().0;
            let self_id = var_id(closure.file, token);
            frame.declare("self", self_id);
            inner.vars.insert(self_id, self_value);
        }
        let fname = closure.name.clone();
        for param in closure.body.parameters() {
            match param {
                Parameter::Name(token) => {
                    let name = token_name(token);
                    let mut value = args.next().unwrap_or_else(Value::nil);
                    if !entry {
                        value = value.step(loc, &format!("passed to `{fname}` as `{name}`"));
                    }
                    if value.path.is_none() || entry {
                        value.path = value.path.or_else(|| Some(Rc::from(name.as_str())));
                    }
                    let pid = var_id(closure.file, token);
                    frame.declare(&name, pid);
                    inner.invalidate_paths(pid, None);
                    inner.vars.insert(pid, value);
                }
                Parameter::Ellipsis(_) => {
                    frame.varargs = args.by_ref().collect();
                }
                _ => {}
            }
        }
        let body_end = self.exec_block(&mut frame, closure.body.block(), inner);
        if frame.summary.is_some() && !body_end.dead {
            let mut end = body_end.clone();
            self.record_summary_return(&mut frame, &mut end, None);
        }
        let falls_through = !body_end.dead;
        let mut states = std::mem::take(&mut frame.return_states);
        states.push(body_end);
        *state = State::join_all(states);
        self.stack.pop();
        let mut returns = frame.returns.take().unwrap_or_default();
        if falls_through && !returns.is_empty() {
            returns = returns.iter().map(|v| v.join(&Value::nil())).collect();
        }
        if returns.is_empty() {
            returns.push(Value::nil());
        }
        // Conditions refer to the callee's variables: they mean nothing here.
        for value in &mut returns {
            value.condition = None;
        }
        (returns, frame.summary.take())
    }

    /// What `closure` guarantees about its parameters (computed once, with
    /// placeholder "probe" arguments).
    pub(crate) fn summary_of(
        &mut self,
        closure: &Rc<Closure<'a>>,
        base: &State<'a>,
    ) -> Option<Rc<Summary>> {
        let key = closure.key();
        if let Some(cached) = self.summaries.get(&key) {
            return cached.clone();
        }
        if self.stack.len() >= self.config.max_call_depth {
            return None;
        }
        self.summaries.insert(key, None);
        let saved_entry = self.entry.take();
        let saved_budget = self.budget;
        let saved_peek = self.peek;
        self.quiet += 1;
        self.peek = 0;
        self.budget = 8_000;
        let mut args = Vec::new();
        let mut params = Vec::new();
        if closure.is_method {
            args.push(Value::unknown());
        }
        for param in closure.body.parameters() {
            if let Parameter::Name(token) = param {
                let loc = self.loc(closure.file, token);
                let source = self.new_source(
                    SourceKind::Probe,
                    token_name(token),
                    String::new(),
                    loc,
                    None,
                );
                params.push((var_id(closure.file, token), source.id));
                args.push(self.tainted(source));
            }
        }
        let collector = SummaryCollector {
            params: params.clone(),
            truthy: None,
            exit: None,
            may_return_truthy: false,
        };
        let mut state = base.clone();
        let (_, collector) = self.call_closure_with(
            &mut state,
            closure.clone(),
            args,
            None,
            closure.loc,
            false,
            Some(collector),
        );
        self.quiet -= 1;
        self.peek = saved_peek;
        self.budget = saved_budget;
        self.entry = saved_entry;
        let n = params.len();
        let offset = usize::from(closure.is_method);
        let summary = collector.map(|c| {
            let pad = |v: Option<Vec<Checks>>| -> Vec<Checks> {
                let mut out = vec![0; offset];
                out.extend(v.unwrap_or_else(|| vec![0; n]));
                out
            };
            Summary {
                truthy: if c.may_return_truthy {
                    pad(c.truthy)
                } else {
                    pad(None)
                },
                exit: pad(c.exit),
            }
        });
        let summary = summary.map(Rc::new);
        self.summaries.insert(key, summary.clone());
        summary
    }

    // ------------------------------------------------------------------
    // Builtins
    // ------------------------------------------------------------------

    #[allow(clippy::too_many_arguments)]
    fn call_builtin(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        builtin: Builtin,
        args: Vec<Value<'a>>,
        arg_exprs: &[&'a Expression],
        loc: Loc,
        statement: bool,
        display: &str,
    ) -> Vec<Value<'a>> {
        let arg = |i: usize| args.get(i).cloned().unwrap_or_else(Value::nil);
        let derived_with = |value: &Value<'a>, kind: Kind<'a>, add: Checks| -> Value<'a> {
            let mut v = Value::of(kind);
            for flow in value.deep_flows() {
                v.add_flows([Flow {
                    raw: false,
                    checks: flow.checks | add,
                    ..flow
                }]);
            }
            v
        };
        match builtin {
            Builtin::Typeof | Builtin::Type => {
                let name = match &arg(0).kind {
                    _ if arg(0).is_tainted() => None,
                    Kind::Number(_) => Some("number"),
                    Kind::Str(_) => Some("string"),
                    Kind::Bool(_) => Some("boolean"),
                    Kind::Table(_) => Some("table"),
                    Kind::Func(_) => Some("function"),
                    Kind::Nil => Some("nil"),
                    _ => None,
                };
                vec![Value::of(Kind::Str(name.map(Rc::from)))]
            }
            Builtin::Tonumber => {
                let a = arg(0);
                let kind = match &a.kind {
                    Kind::Number(n) => Kind::Number(*n),
                    Kind::Str(Some(s)) => Kind::Number(number_literal(s)),
                    _ => Kind::Number(None),
                };
                vec![derived_with(&a, kind, check::TYPE_NUMBER)]
            }
            Builtin::Tostring => vec![derived_with(&arg(0), Kind::Str(None), check::TYPE_STRING)],
            Builtin::Assert => {
                if let Some(expr) = arg_exprs.first() {
                    let refinement = self.refine_condition(frame, state, expr);
                    self.apply_facts(state, &refinement.on_true);
                    if let Some(first) = args.first() {
                        let mut v = first.clone();
                        if let Some(target) = self.target_of(frame, expr) {
                            if let Some(checks) = refinement.on_true.map.get(&target) {
                                v.add_checks(*checks);
                            }
                        }
                        let mut out = vec![v];
                        out.extend(args.into_iter().skip(1));
                        return out;
                    }
                }
                args
            }
            Builtin::Error => {
                state.dead = true;
                vec![Value::nil()]
            }
            Builtin::Pcall | Builtin::Xpcall => {
                let skip = if builtin == Builtin::Xpcall { 2 } else { 1 };
                let callee = arg(0);
                let rest: Vec<Value<'a>> = args.iter().skip(skip).cloned().collect();
                let rest_exprs: Vec<&'a Expression> =
                    arg_exprs.iter().skip(skip).copied().collect();
                let callee_display = arg_exprs.first().map(|e| compact(*e)).unwrap_or_default();
                let mut s = state.clone();
                // `pcall(store.SetAsync, store, key, value)` is `store:SetAsync(key, value)`.
                let method = arg_exprs
                    .first()
                    .and_then(|e| method_reference(e, rest_exprs.first().copied()));
                let results = match method {
                    Some((receiver_display, name)) => {
                        let receiver = rest.first().cloned().unwrap_or_default();
                        self.call_method(
                            frame,
                            &mut s,
                            &receiver,
                            &name,
                            rest[1..].to_vec(),
                            &rest_exprs[1..],
                            None,
                            &receiver_display,
                            loc,
                            false,
                        )
                    }
                    None => self.call_value(
                        frame,
                        &mut s,
                        &callee,
                        rest,
                        &rest_exprs,
                        None,
                        &callee_display,
                        loc,
                        false,
                    ),
                };
                // The call may fail at any point: keep the state of both outcomes.
                *state = std::mem::take(state).join(s);
                let mut out = vec![Value::of(Kind::Bool(None))];
                out.extend(results);
                out
            }
            Builtin::Select => {
                let first = arg(0);
                if first.str_const() == Some("#") {
                    return vec![Value::of(Kind::Number(None))];
                }
                let mut joined = Value::nil();
                for (i, v) in args.iter().enumerate().skip(1) {
                    joined = if i == 1 { v.clone() } else { joined.join(v) };
                }
                vec![joined]
            }
            Builtin::Require => vec![self.require(frame, &arg(0), arg_exprs.first().copied(), loc)],
            Builtin::Loadstring => {
                self.check_value(
                    RuleId::Ls004,
                    SinkKind::Code,
                    &arg(0),
                    loc,
                    &format!("is executed as code by `{display}`"),
                );
                vec![Value::unknown()]
            }
            Builtin::Getfenv => vec![Value::obj(ObjClass::GlobalEnv, None, "getfenv()")],
            Builtin::Setfenv => {
                for a in &args {
                    self.check_value(
                        RuleId::Ls004,
                        SinkKind::Code,
                        a,
                        loc,
                        "is passed to `setfenv`",
                    );
                }
                vec![Value::unknown()]
            }
            Builtin::Pairs | Builtin::Ipairs => {
                vec![
                    Value::of(Kind::Func(Rc::new(vec![Func::Builtin(Builtin::Next)]))),
                    arg(0),
                    Value::nil(),
                ]
            }
            Builtin::Next => vec![Value::unknown(), self.element_of(&arg(0))],
            Builtin::Unpack | Builtin::TableUnpack => {
                let element = self.element_of(&arg(0));
                vec![element.clone(), element.clone(), element.clone(), element]
            }
            Builtin::Rawget => {
                let key = arg(1);
                let key = match key.str_const() {
                    Some(s) if !key.is_tainted() => Key::Name(Rc::from(s)),
                    _ => Key::Dynamic(key, None),
                };
                vec![self.index_value(&arg(0), key, loc, display, "[...]")]
            }
            Builtin::Setmetatable => vec![with_metatable(arg(0), &arg(1))],
            Builtin::Rawset | Builtin::TableClone | Builtin::TableFreeze => vec![arg(0)],
            Builtin::Rawequal => vec![Value::of(Kind::Bool(None))],
            Builtin::Getmetatable => vec![Value::unknown()],
            Builtin::Print | Builtin::TableSort => Vec::new(),
            Builtin::Spawn => {
                let (index, rest_from) = if display.ends_with("delay") {
                    (1, 2)
                } else {
                    (0, 1)
                };
                let callee = arg(index);
                let rest: Vec<Value<'a>> = args.iter().skip(rest_from).cloned().collect();
                for func in callee.funcs() {
                    if let Func::Closure(closure) = func {
                        let mut s = state.clone();
                        let _ = self.call_closure(&mut s, closure, rest.clone(), None, loc, false);
                    }
                }
                if display.contains("wrap") {
                    return vec![callee];
                }
                vec![Value::unknown()]
            }
            Builtin::Wait => vec![Value::of(Kind::Number(None))],
            Builtin::TableInsert => {
                let value = args.last().cloned().unwrap_or_default();
                if let Some(expr) = arg_exprs.first() {
                    if let Some(target) = self.target_of(frame, expr) {
                        let (root, keys): (u64, Vec<Rc<str>>) = match &target {
                            Target::Var(id) => (*id, Vec::new()),
                            Target::Path(id, path) => {
                                (*id, path.split('.').map(Rc::from).collect())
                            }
                        };
                        if let Some(current) = state.vars.get(&root).cloned() {
                            if let Some(updated) = insert_dynamic(&current, &keys, value) {
                                state.vars.insert(root, updated);
                            }
                        }
                    }
                }
                Vec::new()
            }
            Builtin::TableFind => vec![Value::of(Kind::Number(None))],
            Builtin::TableConcat => {
                vec![derived_with(&arg(0), Kind::Str(None), check::TYPE_STRING)]
            }
            Builtin::TableRemove => vec![self.element_of(&arg(0))],
            Builtin::TableCreate => {
                let table = Table {
                    dynamic: Some(Box::new(arg(1))),
                    fresh_frame: Some(frame.id),
                    ..Table::default()
                };
                vec![Value::of(Kind::Table(Rc::new(table)))]
            }
            Builtin::MathClamp => {
                let bounds_trusted = !arg(1).is_tainted() && !arg(2).is_tainted();
                let add = check::TYPE_NUMBER | if bounds_trusted { check::BOUNDS } else { 0 };
                let mut v = derived_with(&arg(0), Kind::Number(None), add);
                v.add_flows(arg(1).derived().flows);
                v.add_flows(arg(2).derived().flows);
                vec![v]
            }
            Builtin::MathMin | Builtin::MathMax => {
                let bound = if builtin == Builtin::MathMin {
                    check::UPPER
                } else {
                    check::LOWER
                };
                let mut v = Value::of(Kind::Number(None));
                let any_trusted = args.iter().any(|a| !a.is_tainted());
                for a in &args {
                    let add = check::TYPE_NUMBER | if any_trusted { bound } else { 0 };
                    v.add_flows(derived_with(a, Kind::Unknown, add).flows);
                }
                vec![v]
            }
            Builtin::MathAbs => vec![derived_with(
                &arg(0),
                Kind::Number(None),
                check::TYPE_NUMBER | check::LOWER,
            )],
            Builtin::MathFloor | Builtin::MathOther => {
                let mut v = Value::of(Kind::Number(None));
                for a in &args {
                    v.add_flows(derived_with(a, Kind::Unknown, check::TYPE_NUMBER).flows);
                }
                vec![v]
            }
            Builtin::StringLen => vec![length_of(&arg(0))],
            Builtin::StringByte => vec![derived_with(
                &arg(0),
                Kind::Number(None),
                check::TYPE_NUMBER,
            )],
            Builtin::StringMatch
            | Builtin::StringFind
            | Builtin::StringFormat
            | Builtin::StringOther => {
                let mut v = Value::of(Kind::Str(None));
                for a in &args {
                    v.add_flows(a.derived().flows);
                }
                // `string.match` / `string.find` return one value per capture.
                vec![v.clone(), v.clone(), v.clone(), v]
            }
            Builtin::InstanceNew => {
                self.note_expensive("`Instance.new`".to_string());
                let class = arg(0).str_const().map(str::to_string).unwrap_or_default();
                vec![Value::obj(
                    ObjClass::Unknown,
                    None,
                    &format!("Instance.new(\"{class}\")"),
                )]
            }
            Builtin::Clock => {
                self.note_rate_limit();
                vec![Value::of(Kind::Number(None))]
            }
            Builtin::Constructor => {
                let mut v = Value::unknown();
                for a in &args {
                    v.add_flows(derived_with(a, Kind::Unknown, check::TYPE_OTHER).flows);
                }
                vec![v]
            }
            Builtin::Derive => {
                let mut v = Value::unknown();
                for a in &args {
                    v.add_flows(a.derived().flows);
                }
                let _ = statement;
                vec![v]
            }
        }
    }

    /// `require(x)`: evaluates the module when the path resolves statically.
    fn require(
        &mut self,
        frame: &Frame<'a>,
        arg: &Value<'a>,
        expr: Option<&'a Expression>,
        loc: Loc,
    ) -> Value<'a> {
        self.check_value(
            RuleId::Ls004,
            SinkKind::Code,
            arg,
            loc,
            "is passed to `require`",
        );
        let display = expr.map(compact).unwrap_or_default();
        let last = display
            .rsplit(|c: char| !(c.is_alphanumeric() || c == '_'))
            .find(|s| !s.is_empty())
            .unwrap_or("")
            .to_string();
        let file = match (&arg.kind, arg.str_const()) {
            (_, Some(spec)) => self.project.resolve_string_require(frame.file, spec),
            (Kind::Obj(obj), _) => obj
                .instance
                .as_ref()
                .and_then(|path| self.project.resolve_instance(path)),
            _ => None,
        };
        let is_t = last == "t"
            || arg
                .str_const()
                .is_some_and(|s| s == "t" || s.ends_with("/t"));
        if is_t {
            return Value::obj(ObjClass::TLibrary, None, "t");
        }
        match file {
            Some(id) if self.project.files[id].kind == ScriptKind::Module => self.eval_module(id),
            _ => Value::unknown().with_path(format!("require({display})")),
        }
    }

    fn eval_module(&mut self, file: usize) -> Value<'a> {
        match self.modules.get(&file) {
            Some(ModuleState::Done(v)) => return v.clone(),
            Some(ModuleState::Evaluating) => return Value::unknown(),
            None => {}
        }
        let Some(ast) = self.project.files[file].ast.as_ref() else {
            return Value::unknown();
        };
        self.modules.insert(file, ModuleState::Evaluating);
        self.module_eval += 1;
        self.quiet += 1;
        let saved_stack = std::mem::take(&mut self.stack);
        let saved_entry = self.entry.take();
        let saved_budget = self.budget;
        let saved_peek = self.peek;
        self.peek = 0;
        self.budget = 40_000;
        let mut frame = self.top_frame(file);
        let end = self.exec_block(&mut frame, ast.nodes(), State::default());
        let mut states = std::mem::take(&mut frame.return_states);
        states.push(end);
        let final_state = State::join_all(states);
        let exports = frame
            .returns
            .take()
            .and_then(|r| r.into_iter().next())
            .unwrap_or_default();
        self.statics
            .entry(file)
            .or_insert_with(|| Rc::new(final_state.vars));
        self.stack = saved_stack;
        self.entry = saved_entry;
        self.budget = saved_budget;
        self.peek = saved_peek;
        self.quiet -= 1;
        self.module_eval -= 1;
        let mut exports = exports;
        if exports.path.is_none() {
            let name = self.project.files[file]
                .instance_path
                .last()
                .cloned()
                .unwrap_or_default();
            exports.path = Some(Rc::from(name.as_str()));
        }
        self.modules
            .insert(file, ModuleState::Done(exports.clone()));
        exports
    }

    // ------------------------------------------------------------------
    // Methods
    // ------------------------------------------------------------------

    #[allow(clippy::too_many_arguments)]
    pub(crate) fn call_method(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        recv: &Value<'a>,
        name: &str,
        args: Vec<Value<'a>>,
        arg_exprs: &[&'a Expression],
        callee_path: Option<&[String]>,
        recv_display: &str,
        loc: Loc,
        statement: bool,
    ) -> Vec<Value<'a>> {
        let display = format!("{recv_display}:{name}");
        self.note_rate_limit_name(&display);
        if name.ends_with("Async") {
            self.note_expensive(format!("`{display}()`"));
        }
        if name == "Clone" {
            self.note_expensive(format!("`{display}()`"));
        }
        if name == "GetServerTimeNow" {
            self.note_rate_limit();
        }
        // Event connections: remote handlers are the sources of untrusted data.
        if matches!(name, "Connect" | "Once" | "ConnectParallel") {
            let funcs = args.first().map(Value::funcs).unwrap_or_default();
            let top_level = frame.closure.is_none();
            let rate_limited = arg_exprs.first().is_some_and(|e| {
                matches!(unwrap_expr(e), Expression::FunctionCall(_))
                    && has_rate_limit_word(&compact(*e))
            });
            let kind = if let Some(remote) = recv_display.strip_suffix(".OnServerEvent") {
                Some(EntryKind::Remote {
                    event: "OnServerEvent",
                    remote: remote.to_string(),
                })
            } else if recv_display.ends_with(".Chatted") {
                Some(EntryKind::Chat)
            } else if recv_display.ends_with(".PlayerAdded") {
                Some(EntryKind::Callback { player_param: true })
            } else {
                Some(EntryKind::Callback {
                    player_param: false,
                })
            };
            if let Some(kind) = kind {
                self.register_entry(funcs, kind, loc, state, rate_limited, top_level);
            }
            return vec![Value::unknown()];
        }
        if let Some(path) = callee_path {
            self.check_custom_sinks(path, &args, loc, &display);
            if let Some(checks) = self.sanitizer_checks(path) {
                for expr in arg_exprs {
                    if let Some(target) = self.target_of(frame, expr) {
                        state.add_checks(&target, checks);
                    }
                }
                let mut result = args.into_iter().next().unwrap_or_default();
                result.add_checks(checks);
                return vec![result];
            }
        }
        self.check_method_sinks(frame, state, recv, name, &args, recv_display, loc);

        // Methods of tables (modules, OOP objects).
        if let Kind::Table(table) = &recv.kind {
            if let Some(field) = table.fields.get(name) {
                if matches!(field.kind, Kind::Func(_)) {
                    let mut full_args = vec![recv.clone()];
                    full_args.extend(args);
                    let mut full_exprs: Vec<&'a Expression> = Vec::new();
                    // `self` has no expression; keep positions aligned.
                    full_exprs.extend(arg_exprs.iter().copied());
                    let field = field.clone();
                    return self.call_method_closure(
                        frame, state, &field, full_args, arg_exprs, loc, statement, &display,
                    );
                }
            }
        }
        if let Some(v) = self.model_method(
            frame,
            state,
            recv,
            name,
            &args,
            arg_exprs,
            recv_display,
            loc,
        ) {
            return v;
        }
        // Unknown method.
        let mut result = Value::unknown();
        if recv.is_tainted() {
            if sinks::is_query_method(name) || matches!(name, "GetAttribute" | "GetAttributes") {
                for flow in &recv.flows {
                    result.add_flows([Flow {
                        checks: flow.checks & check::INHERITED_BY_FIELDS,
                        raw: true,
                        instance_data: true,
                        ..flow.clone()
                    }]);
                }
            } else if sinks::is_string_method(name) {
                if name == "len" {
                    return vec![length_of(recv)];
                }
                result.kind = Kind::Str(None);
                result.add_flows(recv.derived().flows);
                if matches!(name, "match" | "find" | "gmatch") {
                    for arg in &args {
                        result.add_flows(arg.derived().flows);
                    }
                    return vec![result.clone(), result.clone(), result.clone(), result];
                }
            } else {
                result.add_flows(recv.derived().flows);
            }
        }
        let lookup =
            name.starts_with("Get") || name.starts_with("Find") || name.starts_with("Wait");
        if lookup && !recv.is_tainted() {
            if let Some(expr) = arg_exprs.first() {
                if args.first().is_some_and(|a| a.is_tainted()) {
                    result.witness = self.target_of(frame, expr);
                }
            }
        } else {
            for arg in &args {
                result.add_flows(arg.derived().flows);
            }
        }
        result.player_rel = recv.player_rel;
        result.path = Some(Rc::from(format!("{display}()").as_str()));
        vec![result]
    }

    #[allow(clippy::too_many_arguments)]
    fn call_method_closure(
        &mut self,
        frame: &mut Frame<'a>,
        state: &mut State<'a>,
        field: &Value<'a>,
        args: Vec<Value<'a>>,
        arg_exprs: &[&'a Expression],
        loc: Loc,
        statement: bool,
        display: &str,
    ) -> Vec<Value<'a>> {
        let mut results: Option<Vec<Value<'a>>> = None;
        let funcs = field.funcs();
        let single = funcs.len() == 1;
        let mut states = Vec::new();
        for func in funcs {
            let mut s = if single {
                std::mem::take(state)
            } else {
                state.clone()
            };
            let r = match &func {
                Func::Closure(closure) => {
                    let tainted_targets: Vec<(usize, Target)> = arg_exprs
                        .iter()
                        .enumerate()
                        .filter(|(i, _)| args.get(i + 1).is_some_and(|a| a.is_tainted()))
                        .filter_map(|(i, e)| self.target_of(frame, e).map(|t| (i, t)))
                        .collect();
                    // Plain functions stored in a table and called with `:`
                    // receive the table as first argument.
                    let r =
                        self.call_closure(&mut s, closure.clone(), args.clone(), None, loc, false);
                    if !tainted_targets.is_empty() && !s.dead {
                        if let Some(summary) = self.summary_of(closure, &s) {
                            for (i, target) in tainted_targets {
                                if let Some(checks) = summary.exit.get(i + 1) {
                                    s.add_checks(&target, *checks);
                                }
                            }
                        }
                    }
                    r
                }
                Func::Builtin(b) => self.call_builtin(
                    frame,
                    &mut s,
                    *b,
                    args[1..].to_vec(),
                    arg_exprs,
                    loc,
                    statement,
                    display,
                ),
            };
            states.push(s);
            results = Some(match results {
                None => r,
                Some(prev) => join_lists(&prev, &r),
            });
        }
        *state = State::join_all(states);
        results.unwrap_or_else(|| vec![Value::nil()])
    }

    /// Models of Roblox API methods. `None` when the method is not modelled.
    #[allow(clippy::too_many_arguments)]
    fn model_method(
        &mut self,
        frame: &mut Frame<'a>,
        _state: &mut State<'a>,
        recv: &Value<'a>,
        name: &str,
        args: &[Value<'a>],
        arg_exprs: &[&'a Expression],
        recv_display: &str,
        loc: Loc,
    ) -> Option<Vec<Value<'a>>> {
        let arg = |i: usize| args.get(i).cloned().unwrap_or_else(Value::nil);
        let display = format!("{recv_display}:{name}");
        let child = |this: &Self, child_name: &str| -> Value<'a> {
            let mut v = this.index_value(
                recv,
                Key::Name(Rc::from(child_name)),
                loc,
                recv_display,
                &format!(".{child_name}"),
            );
            v.witness = None;
            v
        };
        let _ = frame;
        let result = match name {
            "GetService" => match arg(0).str_const() {
                Some(service) => Value::obj(
                    ObjClass::Service(Rc::from(service)),
                    Some(vec![service.to_string()]),
                    service,
                ),
                None => Value::unknown(),
            },
            "FindFirstChild" | "WaitForChild" if !recv.is_tainted() => match arg(0).str_const() {
                Some(child_name) if !arg(0).is_tainted() => child(self, child_name),
                _ => {
                    let mut v = Value::unknown().with_path(format!("{display}(...)"));
                    v.player_rel = recv.player_rel;
                    if arg(0).is_tainted() {
                        v.witness = arg_exprs.first().and_then(|e| self.target_of(frame, e));
                    }
                    v
                }
            },
            "GetDataStore" | "GetOrderedDataStore" | "GetGlobalDataStore" => {
                Value::obj(ObjClass::DataStore, None, &format!("{display}(...)"))
            }
            "GetSortedMap" | "GetQueue" | "GetHashMap" => {
                Value::obj(ObjClass::MemoryStore, None, &format!("{display}(...)"))
            }
            "InvokeClient" => {
                let description = format!(
                    "the value returned by the client from `{recv_display}:InvokeClient()` is client-controlled"
                );
                let source = self.new_source(
                    SourceKind::RemoteParameter,
                    format!("{recv_display}:InvokeClient()"),
                    description,
                    loc,
                    None,
                );
                let mut v = self.tainted(source);
                v.path = Some(Rc::from("InvokeClient result"));
                return Some(vec![v.clone(), v.clone(), v]);
            }
            "FilterStringAsync" | "FilterAndTranslateStringAsync"
                if recv.is_service("TextService") =>
            {
                let mut v = arg(0).derived();
                v.kind = Kind::Obj(Rc::new(super::value::Obj {
                    class: ObjClass::TextFilterResult,
                    instance: None,
                }));
                v
            }
            "GetNonChatStringForBroadcastAsync"
            | "GetNonChatStringForUserAsync"
            | "GetChatForUserAsync"
                if matches!(recv.class(), Some(ObjClass::TextFilterResult))
                    || recv.is_tainted() =>
            {
                let mut v = recv.derived();
                v.kind = Kind::Str(None);
                v.add_checks(check::FILTERED | check::TYPE_STRING);
                v
            }
            "FilterStringForBroadcast" | "FilterStringAsync" if recv.is_service("Chat") => {
                let mut v = arg(0).derived();
                v.kind = Kind::Str(None);
                v.add_checks(check::FILTERED | check::TYPE_STRING);
                v
            }
            "UrlEncode" if recv.is_service("HttpService") => {
                let mut v = arg(0).derived();
                v.kind = Kind::Str(None);
                v.add_checks(check::ENCODED | check::TYPE_STRING);
                v
            }
            "JSONEncode" if recv.is_service("HttpService") => {
                let mut v = arg(0).derived();
                v.kind = Kind::Str(None);
                v
            }
            "JSONDecode" if recv.is_service("HttpService") => {
                let mut v = Value::unknown();
                for flow in arg(0).flows {
                    v.add_flows([Flow {
                        raw: true,
                        checks: flow.checks & check::TRUSTED,
                        ..flow
                    }]);
                }
                v
            }
            "GenerateGUID" | "GetAsync" | "PostAsync" | "RequestAsync" | "GetSecret"
                if recv.is_service("HttpService") =>
            {
                Value::unknown().with_path(format!("{display}()"))
            }
            "IsA" | "IsDescendantOf" | "IsAncestorOf" | "HasTag" => Value::of(Kind::Bool(None)),
            "GetPlayerFromCharacter" | "GetPlayerByUserId" if !recv.is_tainted() => {
                let mut v = Value::unknown().with_path(format!("{display}(...)"));
                if arg(0).is_tainted() {
                    v.witness = arg_exprs.first().and_then(|e| self.target_of(frame, e));
                }
                v
            }
            "Clone" if !recv.is_tainted() => Value::unknown().with_path(format!("{display}()")),
            "GetServerTimeNow" => Value::of(Kind::Number(None)),
            _ => return None,
        };
        Some(vec![result])
    }
}

/// `obj.Method` passed together with `obj` (as in `pcall(obj.Method, obj, ...)`):
/// returns the receiver text and the method name.
fn method_reference(
    callee: &Expression,
    receiver: Option<&Expression>,
) -> Option<(String, String)> {
    let receiver = receiver?;
    let Expression::Var(full_moon::ast::Var::Expression(var)) = unwrap_expr(callee) else {
        return None;
    };
    let suffixes: Vec<&full_moon::ast::Suffix> = var.suffixes().collect();
    let (last, init) = suffixes.split_last()?;
    let full_moon::ast::Suffix::Index(full_moon::ast::Index::Dot { name, .. }) = last else {
        return None;
    };
    let mut base = compact(var.prefix());
    for suffix in init {
        base.push_str(&compact(*suffix));
    }
    if base != compact(receiver) {
        return None;
    }
    let name = token_name(name);
    // Only method-like names (PascalCase Roblox methods).
    if !name.chars().next().is_some_and(|c| c.is_ascii_uppercase()) {
        return None;
    }
    Some((base, name))
}

/// `setmetatable(object, Class)`: methods reachable through `__index` (or
/// defined on the metatable itself, as in `Class.__index = Class`) become
/// visible on the object, so `object:Method()` resolves.
fn with_metatable<'a>(object: Value<'a>, metatable: &Value<'a>) -> Value<'a> {
    let Kind::Table(mt) = &metatable.kind else {
        return object;
    };
    let mut inherited: BTreeMap<Rc<str>, Value<'a>> = BTreeMap::new();
    for (name, value) in &mt.fields {
        if !name.starts_with("__") {
            inherited.insert(name.clone(), value.clone());
        }
    }
    if let Some(Kind::Table(index)) = mt.fields.get("__index").map(|v| &v.kind) {
        for (name, value) in &index.fields {
            inherited
                .entry(name.clone())
                .or_insert_with(|| value.clone());
        }
    }
    let mut table = match &object.kind {
        Kind::Table(t) => (**t).clone(),
        Kind::Unknown => Table::default(),
        _ => return object,
    };
    for (name, value) in inherited {
        table.fields.entry(name).or_insert(value);
    }
    Value {
        kind: Kind::Table(Rc::new(table)),
        ..object
    }
}

fn length_of<'a>(value: &Value<'a>) -> Value<'a> {
    let mut v = Value::of(Kind::Number(None));
    for flow in value.deep_flows() {
        let mut checks =
            check::TYPE_NUMBER | check::LOWER | check::NAN_SAFE | (flow.checks & check::TRUSTED);
        if flow.any(check::LENGTH) {
            checks |= check::UPPER;
        }
        v.add_flows([Flow {
            checks,
            raw: false,
            ..flow
        }]);
    }
    v
}

fn insert_dynamic<'a>(
    value: &Value<'a>,
    keys: &[Rc<str>],
    element: Value<'a>,
) -> Option<Value<'a>> {
    let Kind::Table(table) = &value.kind else {
        return None;
    };
    let mut table = (**table).clone();
    match keys.split_first() {
        None => {
            table.dynamic = Some(Box::new(match table.dynamic.take() {
                Some(d) => d.join(&element),
                None => element,
            }));
        }
        Some((first, rest)) => {
            let inner = table.fields.get(first)?;
            let updated = insert_dynamic(inner, rest, element)?;
            table.fields.insert(first.clone(), updated);
        }
    }
    let mut out = value.clone();
    out.kind = Kind::Table(Rc::new(table));
    Some(out)
}

fn join_lists<'a>(a: &[Value<'a>], b: &[Value<'a>]) -> Vec<Value<'a>> {
    let len = a.len().max(b.len());
    (0..len)
        .map(|i| {
            let x = a.get(i).cloned().unwrap_or_else(Value::nil);
            let y = b.get(i).cloned().unwrap_or_else(Value::nil);
            x.join(&y)
        })
        .collect()
}
