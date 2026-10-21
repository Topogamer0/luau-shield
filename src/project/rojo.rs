//! Minimal Rojo project support: maps files on disk to their place in the
//! DataModel (`ServerScriptService.Shop`, `ReplicatedStorage.Shared.Util`, ...).

use serde_json::Value as Json;
use std::path::{Path, PathBuf};

/// A file mapped by the project, with its instance path from the DataModel root.
#[derive(Debug, Clone)]
pub struct Mapping {
    pub file: PathBuf,
    pub instance_path: Vec<String>,
}

/// Reads a `*.project.json` file and returns every script it maps.
pub fn load_project(project_file: &Path) -> Result<Vec<Mapping>, String> {
    let mut out = Vec::new();
    load_into(project_file, Vec::new(), &mut out, 0)?;
    Ok(out)
}

fn load_into(
    project_file: &Path,
    root_path: Vec<String>,
    out: &mut Vec<Mapping>,
    depth: usize,
) -> Result<(), String> {
    if depth > 8 {
        return Err(format!(
            "{}: nested projects are too deep",
            project_file.display()
        ));
    }
    let text = std::fs::read_to_string(project_file)
        .map_err(|e| format!("cannot read {}: {e}", project_file.display()))?;
    let json: Json = serde_json::from_str(&text)
        .map_err(|e| format!("invalid Rojo project {}: {e}", project_file.display()))?;
    let tree = json
        .get("tree")
        .ok_or_else(|| format!("{}: missing `tree`", project_file.display()))?;
    let dir = project_file.parent().unwrap_or(Path::new("."));

    // A project whose root is not the DataModel is a model/library: its root
    // instance is named after the project.
    let mut path = root_path;
    let is_data_model = tree.get("$className").and_then(Json::as_str) == Some("DataModel");
    if !is_data_model && path.is_empty() {
        let name = json.get("name").and_then(Json::as_str).unwrap_or("Project");
        path.push(name.to_string());
    }
    map_node(tree, path, dir, out, depth);
    Ok(())
}

fn map_node(node: &Json, path: Vec<String>, dir: &Path, out: &mut Vec<Mapping>, depth: usize) {
    if let Some(fs_path) = node.get("$path").and_then(|p| {
        p.as_str()
            .or_else(|| p.get("optional").and_then(Json::as_str))
    }) {
        map_fs(&dir.join(fs_path), path.clone(), out, depth);
    }
    if let Some(children) = node.as_object() {
        for (name, child) in children {
            if name.starts_with('$') || !child.is_object() {
                continue;
            }
            let mut child_path = path.clone();
            child_path.push(name.clone());
            map_node(child, child_path, dir, out, depth);
        }
    }
}

/// The instance name of a script file, and whether it is an `init` file.
pub fn script_name(file_name: &str) -> Option<(String, bool)> {
    let stem = file_name
        .strip_suffix(".luau")
        .or_else(|| file_name.strip_suffix(".lua"))?;
    let stem = stem
        .strip_suffix(".server")
        .or_else(|| stem.strip_suffix(".client"))
        .unwrap_or(stem);
    Some((stem.to_string(), stem == "init"))
}

fn map_fs(path: &Path, inst: Vec<String>, out: &mut Vec<Mapping>, depth: usize) {
    if path.is_file() {
        let file_name = path.file_name().and_then(|n| n.to_str()).unwrap_or("");
        if file_name.ends_with(".project.json") {
            let _ = load_into(path, inst, out, depth + 1);
        } else if script_name(file_name).is_some() {
            out.push(Mapping {
                file: path.to_path_buf(),
                instance_path: inst,
            });
        }
        return;
    }
    let Ok(entries) = std::fs::read_dir(path) else {
        return;
    };
    let mut entries: Vec<PathBuf> = entries.flatten().map(|e| e.path()).collect();
    entries.sort();
    for entry in entries {
        let file_name = entry
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("")
            .to_string();
        if entry.is_dir() {
            let mut child = inst.clone();
            child.push(file_name);
            map_fs(&entry, child, out, depth);
        } else if let Some((name, is_init)) = script_name(&file_name) {
            let instance_path = if is_init {
                inst.clone()
            } else {
                let mut child = inst.clone();
                child.push(name);
                child
            };
            out.push(Mapping {
                file: entry,
                instance_path,
            });
        }
    }
}
