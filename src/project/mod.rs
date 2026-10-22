//! Loading the files to analyse: discovery, parsing, run contexts (server /
//! client / replicated) and static `require` resolution.

pub mod rojo;

use crate::finding::ParseFailure;
use crate::suppress::Suppressions;
use full_moon::LuaVersion;
use full_moon::ast::Ast;
use globset::GlobSet;
use std::collections::HashMap;
use std::path::{Component, Path, PathBuf};

/// What kind of script a file is.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ScriptKind {
    /// `*.server.luau`
    Script,
    /// `*.client.luau`
    LocalScript,
    Module,
}

/// Where a file's code runs, and who can read its source.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum RunContext {
    /// Server only; the source never reaches clients.
    Server,
    /// Client only (LocalScripts, modules under StarterPlayer/StarterGui...).
    Client,
    /// Replicated module: may run on both sides, source visible to clients.
    Shared,
    Unknown,
}

impl RunContext {
    /// Can server-side rules apply to this file?
    pub fn may_run_on_server(self) -> bool {
        !matches!(self, RunContext::Client)
    }

    /// Is the source of this file sent to clients?
    pub fn replicated_to_clients(self) -> bool {
        matches!(self, RunContext::Client | RunContext::Shared)
    }

    pub fn as_str(self) -> &'static str {
        match self {
            RunContext::Server => "server",
            RunContext::Client => "client",
            RunContext::Shared => "replicated",
            RunContext::Unknown => "unknown",
        }
    }
}

pub struct SourceFile {
    pub id: usize,
    pub path: PathBuf,
    /// Display path (relative to the working directory when possible, `/` separators).
    pub rel: String,
    pub text: String,
    pub ast: Option<Ast>,
    pub parse_error: Option<ParseFailure>,
    pub kind: ScriptKind,
    pub context: RunContext,
    /// Path from the DataModel root (or a pseudo path `@fs/...` when unknown).
    pub instance_path: Vec<String>,
    pub suppressions: Suppressions,
}

impl SourceFile {
    pub fn line(&self, line: usize) -> &str {
        self.text.lines().nth(line.saturating_sub(1)).unwrap_or("")
    }

    pub fn is_init(&self) -> bool {
        self.path
            .file_name()
            .and_then(|n| n.to_str())
            .and_then(rojo::script_name)
            .is_some_and(|(_, init)| init)
    }
}

pub struct LoadOptions {
    pub ignore: GlobSet,
    /// Directory the ignore globs are relative to.
    pub ignore_base: PathBuf,
    pub project_file: Option<PathBuf>,
}

pub struct Project {
    pub files: Vec<SourceFile>,
    instances: HashMap<Vec<String>, usize>,
    by_path: HashMap<PathBuf, usize>,
    luaurc: Vec<(PathBuf, HashMap<String, PathBuf>)>,
    pub warnings: Vec<String>,
    /// Files that were found but could not be read.
    pub unreadable: Vec<ParseFailure>,
}

const ALWAYS_IGNORED_DIRS: &[&str] = &[
    "Packages",
    "DevPackages",
    "ServerPackages",
    "node_modules",
    ".git",
    "target",
    ".pesde",
    "roblox_packages",
];

const SERVICES: &[&str] = &[
    "Workspace",
    "Players",
    "Lighting",
    "ReplicatedFirst",
    "ReplicatedStorage",
    "ServerScriptService",
    "ServerStorage",
    "StarterGui",
    "StarterPack",
    "StarterPlayer",
    "Teams",
    "SoundService",
    "Chat",
    "TextChatService",
];

pub fn normalize(path: &Path) -> PathBuf {
    let mut out = PathBuf::new();
    for component in path.components() {
        match component {
            Component::CurDir => {}
            Component::ParentDir => {
                if !out.pop() {
                    out.push("..");
                }
            }
            other => out.push(other.as_os_str()),
        }
    }
    out
}

fn absolute(path: &Path) -> PathBuf {
    let joined = if path.is_absolute() {
        path.to_path_buf()
    } else {
        std::env::current_dir()
            .map(|cwd| cwd.join(path))
            .unwrap_or_else(|_| path.to_path_buf())
    };
    normalize(&joined)
}

fn display_path(path: &Path) -> String {
    let abs = absolute(path);
    let shown = std::env::current_dir()
        .ok()
        .and_then(|cwd| {
            abs.strip_prefix(normalize(&cwd))
                .ok()
                .map(Path::to_path_buf)
        })
        .unwrap_or(abs);
    shown.to_string_lossy().replace('\\', "/")
}

fn is_lua_file(path: &Path) -> bool {
    matches!(
        path.extension().and_then(|e| e.to_str()),
        Some("luau") | Some("lua")
    )
}

fn script_kind(path: &Path) -> ScriptKind {
    let name = path.file_name().and_then(|n| n.to_str()).unwrap_or("");
    if name.ends_with(".server.luau") || name.ends_with(".server.lua") {
        ScriptKind::Script
    } else if name.ends_with(".client.luau") || name.ends_with(".client.lua") {
        ScriptKind::LocalScript
    } else {
        ScriptKind::Module
    }
}

fn context_from_hint(name: &str) -> Option<RunContext> {
    match name.to_ascii_lowercase().as_str() {
        "server" | "serverscriptservice" | "serverstorage" => Some(RunContext::Server),
        "client"
        | "starterplayer"
        | "starterplayerscripts"
        | "startercharacterscripts"
        | "startergui"
        | "starterpack"
        | "replicatedfirst" => Some(RunContext::Client),
        "shared" | "common" | "replicatedstorage" | "workspace" => Some(RunContext::Shared),
        _ => None,
    }
}

fn context_for(kind: ScriptKind, location: &[String]) -> RunContext {
    match kind {
        ScriptKind::Script => RunContext::Server,
        ScriptKind::LocalScript => RunContext::Client,
        ScriptKind::Module => location
            .iter()
            .rev()
            .find_map(|segment| context_from_hint(segment))
            .unwrap_or(RunContext::Unknown),
    }
}

/// Context of a file placed by the Rojo project: the service at the root of
/// its instance path decides, inner folder names are only a fallback.
fn context_for_instance(kind: ScriptKind, instance: &[String]) -> RunContext {
    if kind != ScriptKind::Module {
        return context_for(kind, instance);
    }
    match instance.first().map(String::as_str) {
        Some("ServerScriptService" | "ServerStorage") => RunContext::Server,
        Some(
            "ReplicatedStorage" | "Workspace" | "Lighting" | "Teams" | "SoundService" | "Chat"
            | "TextChatService" | "MaterialService",
        ) => RunContext::Shared,
        Some("ReplicatedFirst" | "StarterPlayer" | "StarterGui" | "StarterPack") => {
            RunContext::Client
        }
        _ => context_for(kind, instance),
    }
}

fn find_upwards(start: &Path, name: &str) -> Option<PathBuf> {
    let mut dir = Some(start);
    while let Some(d) = dir {
        let candidate = d.join(name);
        if candidate.is_file() {
            return Some(candidate);
        }
        dir = d.parent();
    }
    None
}

impl Project {
    /// Discovers, reads and parses every `.luau`/`.lua` file under `paths`.
    pub fn load(paths: &[PathBuf], options: &LoadOptions) -> Result<Project, String> {
        let warnings = Vec::new();
        let mut files: Vec<PathBuf> = Vec::new();
        let ignore_base = absolute(&options.ignore_base);
        for path in paths {
            if !path.exists() {
                return Err(format!("path not found: {}", path.display()));
            }
            if path.is_file() {
                files.push(absolute(path));
                continue;
            }
            let walker = walkdir::WalkDir::new(path)
                .follow_links(true)
                .sort_by_file_name()
                .into_iter()
                .filter_entry(|entry| {
                    entry.depth() == 0
                        || !(entry.file_type().is_dir()
                            && entry
                                .file_name()
                                .to_str()
                                .is_some_and(|n| ALWAYS_IGNORED_DIRS.contains(&n)))
                });
            for entry in walker.flatten() {
                if entry.file_type().is_file() && is_lua_file(entry.path()) {
                    let abs = absolute(entry.path());
                    let relative = abs.strip_prefix(&ignore_base).unwrap_or(&abs);
                    if options.ignore.is_match(relative) {
                        continue;
                    }
                    files.push(abs);
                }
            }
        }
        files.sort();
        files.dedup();

        // Rojo project: explicit, or default.project.json next to / above the first path.
        let project_file = match &options.project_file {
            Some(p) if !p.is_file() => {
                return Err(format!("Rojo project not found: {}", p.display()));
            }
            Some(p) => Some(p.clone()),
            None => paths.first().and_then(|p| {
                let abs = absolute(p);
                let dir = if abs.is_dir() {
                    abs
                } else {
                    abs.parent().map(Path::to_path_buf).unwrap_or_default()
                };
                find_upwards(&dir, "default.project.json")
            }),
        };
        let mut mapped: HashMap<PathBuf, Vec<String>> = HashMap::new();
        if let Some(project_file) = &project_file {
            for m in rojo::load_project(project_file)? {
                mapped.entry(absolute(&m.file)).or_insert(m.instance_path);
            }
        }

        let base_dir = paths
            .first()
            .map(|p| absolute(p))
            .map(|p| {
                if p.is_dir() {
                    p
                } else {
                    p.parent().map(Path::to_path_buf).unwrap_or_default()
                }
            })
            .unwrap_or_default();

        let mut project = Project {
            files: Vec::new(),
            instances: HashMap::new(),
            by_path: HashMap::new(),
            luaurc: Vec::new(),
            warnings,
            unreadable: Vec::new(),
        };

        for path in files {
            let id = project.files.len();
            let text = match std::fs::read(&path) {
                Ok(bytes) => match String::from_utf8(bytes) {
                    Ok(text) => text,
                    Err(e) => {
                        project.warnings.push(format!(
                            "{} is not valid UTF-8; invalid bytes were replaced",
                            display_path(&path)
                        ));
                        String::from_utf8_lossy(e.as_bytes()).into_owned()
                    }
                },
                Err(e) => {
                    project.unreadable.push(ParseFailure {
                        file: display_path(&path),
                        line: 1,
                        column: 1,
                        message: format!("cannot read the file: {e}"),
                    });
                    continue;
                }
            };
            // A byte order mark is not Luau.
            let text = text
                .strip_prefix('\u{feff}')
                .map(str::to_string)
                .unwrap_or(text);
            let kind = script_kind(&path);
            let (instance_path, context) = match mapped.get(&path) {
                Some(inst) => (inst.clone(), context_for_instance(kind, inst)),
                None => {
                    let rel = path.strip_prefix(&base_dir).unwrap_or(&path);
                    let mut inst = vec!["@fs".to_string()];
                    let comps: Vec<String> = rel
                        .components()
                        .map(|c| c.as_os_str().to_string_lossy().into_owned())
                        .collect();
                    for (i, comp) in comps.iter().enumerate() {
                        if i + 1 == comps.len() {
                            if let Some((name, is_init)) = rojo::script_name(comp) {
                                if !is_init {
                                    inst.push(name);
                                }
                            }
                        } else {
                            inst.push(comp.clone());
                        }
                    }
                    // Directory hints come from the path inside the project
                    // (relative to the working directory, or to the parent of
                    // the checked directory), so that `src/server/x.luau` is a
                    // server module but `/home/ci/workspace/...` above the
                    // project does not count.
                    let hint_root = std::env::current_dir()
                        .ok()
                        .map(|cwd| normalize(&cwd))
                        .filter(|cwd| path.starts_with(cwd))
                        .or_else(|| base_dir.parent().map(Path::to_path_buf))
                        .unwrap_or_default();
                    let hints: Vec<String> = path
                        .parent()
                        .map(|p| {
                            p.strip_prefix(&hint_root)
                                .unwrap_or(p)
                                .components()
                                .map(|c| c.as_os_str().to_string_lossy().into_owned())
                                .collect()
                        })
                        .unwrap_or_default();
                    (inst, context_for(kind, &hints))
                }
            };
            let (ast, parse_error) = parse(&text, &display_path(&path));
            let suppressions = ast.as_ref().map(Suppressions::from_ast).unwrap_or_default();
            project.instances.entry(instance_path.clone()).or_insert(id);
            project.by_path.insert(path.clone(), id);
            project.files.push(SourceFile {
                id,
                rel: display_path(&path),
                path,
                text,
                ast,
                parse_error,
                kind,
                context,
                instance_path,
                suppressions,
            });
        }
        project.load_luaurc();
        Ok(project)
    }

    fn load_luaurc(&mut self) {
        let mut dirs: Vec<PathBuf> = Vec::new();
        for file in &self.files {
            let mut dir = file.path.parent();
            while let Some(d) = dir {
                if !dirs.contains(&d.to_path_buf()) {
                    dirs.push(d.to_path_buf());
                }
                dir = d.parent();
            }
        }
        for dir in dirs {
            let rc = dir.join(".luaurc");
            let Ok(text) = std::fs::read_to_string(&rc) else {
                continue;
            };
            let Ok(json) = serde_json::from_str::<serde_json::Value>(&relaxed_json(&text)) else {
                self.warnings
                    .push(format!("invalid JSON in {}", rc.display()));
                continue;
            };
            let mut aliases = HashMap::new();
            if let Some(map) = json.get("aliases").and_then(|a| a.as_object()) {
                for (name, target) in map {
                    if let Some(target) = target.as_str() {
                        aliases.insert(name.to_ascii_lowercase(), normalize(&dir.join(target)));
                    }
                }
            }
            self.luaurc.push((dir, aliases));
        }
        // Deepest directories first so that the closest .luaurc wins.
        self.luaurc
            .sort_by_key(|(dir, _)| std::cmp::Reverse(dir.components().count()));
    }

    /// Resolves an instance path (`ServerScriptService.Modules.Economy`) to a file.
    pub fn resolve_instance(&self, path: &[String]) -> Option<usize> {
        if let Some(&id) = self.instances.get(path) {
            return Some(id);
        }
        // Without a Rojo project, absolute paths cannot match exactly: fall
        // back to a unique file whose path ends with the same names.
        let starts_at_service = path.first().is_some_and(|s| SERVICES.contains(&s.as_str()));
        let relative_pseudo = path.first().is_some_and(|s| s == "@fs");
        if !starts_at_service && !relative_pseudo {
            return None;
        }
        let wanted: &[String] = if relative_pseudo { &path[1..] } else { path };
        let last = wanted.last()?;
        let mut best: Option<(usize, usize)> = None;
        let mut ambiguous = false;
        for file in &self.files {
            let inst = &file.instance_path;
            if inst.last() != Some(last) {
                continue;
            }
            let score = inst
                .iter()
                .rev()
                .zip(wanted.iter().rev())
                .take_while(|(a, b)| a.eq_ignore_ascii_case(b))
                .count();
            match best {
                Some((best_score, _)) if score < best_score => {}
                Some((best_score, _)) if score == best_score => ambiguous = true,
                _ => {
                    best = Some((score, file.id));
                    ambiguous = false;
                }
            }
        }
        match best {
            Some((_, id)) if !ambiguous => Some(id),
            _ => None,
        }
    }

    /// Resolves a string require (`"./Economy"`, `"@shared/Util"`, `"@self/x"`).
    pub fn resolve_string_require(&self, from: usize, spec: &str) -> Option<usize> {
        let file = &self.files[from];
        let file_dir = file.path.parent()?;
        let (base, rest) = if let Some(rest) = spec.strip_prefix("@self/") {
            if file.is_init() {
                (file_dir.to_path_buf(), rest)
            } else {
                (
                    file_dir.join(rojo::script_name(file.path.file_name()?.to_str()?)?.0),
                    rest,
                )
            }
        } else if let Some(rest) = spec.strip_prefix("@game/") {
            let segments: Vec<String> = rest.split('/').map(str::to_string).collect();
            return self.resolve_instance(&segments);
        } else if let Some(stripped) = spec.strip_prefix('@') {
            let (alias, rest) = stripped.split_once('/').unwrap_or((stripped, ""));
            let alias = alias.to_ascii_lowercase();
            let target = self.luaurc.iter().find_map(|(dir, aliases)| {
                if file.path.starts_with(dir) {
                    aliases.get(&alias).cloned()
                } else {
                    None
                }
            })?;
            (target, rest)
        } else if spec.starts_with("./") || spec.starts_with("../") {
            // In init files, relative requires start from the parent folder.
            let base = if file.is_init() {
                file_dir.parent()?.to_path_buf()
            } else {
                file_dir.to_path_buf()
            };
            (base, spec)
        } else {
            return None;
        };
        let target = normalize(&base.join(rest));
        let candidates = [
            target.with_extension("luau"),
            target.with_extension("lua"),
            target.join("init.luau"),
            target.join("init.lua"),
            target.clone(),
        ];
        let rest_has_ext = rest.ends_with(".luau") || rest.ends_with(".lua");
        for candidate in candidates.iter().skip(if rest_has_ext { 4 } else { 0 }) {
            if let Some(&id) = self.by_path.get(candidate) {
                return Some(id);
            }
        }
        // `foo.luau` with_extension on `foo.bar` would replace `.bar`: try appending too.
        for ext in ["luau", "lua"] {
            let appended = PathBuf::from(format!("{}.{ext}", target.display()));
            if let Some(&id) = self.by_path.get(&appended) {
                return Some(id);
            }
        }
        None
    }
}

/// `.luaurc` files accept comments and trailing commas: remove them so that
/// they can be read as strict JSON.
fn relaxed_json(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    let chars: Vec<char> = text.chars().collect();
    let mut i = 0;
    let mut in_string = false;
    while i < chars.len() {
        let c = chars[i];
        if in_string {
            out.push(c);
            if c == '\\' && i + 1 < chars.len() {
                out.push(chars[i + 1]);
                i += 2;
                continue;
            }
            if c == '"' {
                in_string = false;
            }
            i += 1;
            continue;
        }
        match c {
            '"' => {
                in_string = true;
                out.push(c);
            }
            '/' if chars.get(i + 1) == Some(&'/') => {
                while i < chars.len() && chars[i] != '\n' {
                    i += 1;
                }
                continue;
            }
            '/' if chars.get(i + 1) == Some(&'*') => {
                i += 2;
                while i + 1 < chars.len() && !(chars[i] == '*' && chars[i + 1] == '/') {
                    i += 1;
                }
                i += 2;
                continue;
            }
            ',' => {
                let next = chars[i + 1..].iter().find(|c| !c.is_whitespace());
                if !matches!(next, Some('}') | Some(']')) {
                    out.push(c);
                }
            }
            _ => out.push(c),
        }
        i += 1;
    }
    out
}

fn parse(text: &str, display: &str) -> (Option<Ast>, Option<ParseFailure>) {
    let result = full_moon::parse_fallible(text, LuaVersion::luau());
    if let Some(error) = result.errors().first() {
        let (start, _) = error.range();
        return (
            None,
            Some(ParseFailure {
                file: display.to_string(),
                line: start.line(),
                column: start.character(),
                message: error.error_message().into_owned(),
            }),
        );
    }
    (Some(result.into_ast()), None)
}
