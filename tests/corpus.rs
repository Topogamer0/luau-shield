//! Runs luau-shield on every entry of `tests/fixtures` and compares the
//! findings with the `-- expect: LSxxx` markers.
//!
//! - a finding without a marker is a false positive;
//! - a marker without a finding is a false negative.
//!
//! Rule directories must be exact. `tests/fixtures/limitations` documents
//! known mistakes of the analyzer: it is reported but never fails the test.
//! Set `LUAU_SHIELD_CORPUS_REPORT=<file>` to write a Markdown summary.

use luau_shield::config::Config;
use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

type Key = (String, usize, String);

fn display(path: &Path) -> String {
    path.to_string_lossy().replace('\\', "/")
}

fn lua_files(entry: &Path) -> Vec<PathBuf> {
    if entry.is_file() {
        return vec![entry.to_path_buf()];
    }
    let mut out = Vec::new();
    for e in walkdir::WalkDir::new(entry).sort_by_file_name() {
        let e = e.unwrap();
        let p = e.path();
        if e.file_type().is_file()
            && matches!(
                p.extension().and_then(|x| x.to_str()),
                Some("luau") | Some("lua")
            )
        {
            out.push(p.to_path_buf());
        }
    }
    out
}

fn markers(entry: &Path) -> BTreeSet<Key> {
    let re = regex::Regex::new(r"--\s*expect:\s*([A-Za-z]{2}\d{3}(?:\s*,\s*[A-Za-z]{2}\d{3})*)")
        .unwrap();
    let mut out = BTreeSet::new();
    for file in lua_files(entry) {
        let text = std::fs::read_to_string(&file).unwrap();
        for (i, line) in text.lines().enumerate() {
            if let Some(caps) = re.captures(line) {
                for code in caps[1].split(',') {
                    out.insert((display(&file), i + 1, code.trim().to_ascii_uppercase()));
                }
            }
        }
    }
    out
}

fn config_for(entry: &Path) -> Config {
    let candidate = if entry.is_dir() {
        entry.join("luau-shield.toml")
    } else {
        PathBuf::from("/nonexistent")
    };
    if candidate.is_file() {
        Config::load(&candidate).unwrap()
    } else {
        Config::default()
    }
}

#[derive(Default)]
struct Tally {
    entries: usize,
    expected: usize,
    true_positives: usize,
    false_positives: Vec<String>,
    false_negatives: Vec<String>,
}

fn run_entry(entry: &Path, tally: &mut Tally, expect_none: bool) {
    let config = config_for(entry);
    let report = luau_shield::check(&[entry.to_path_buf()], &config)
        .unwrap_or_else(|e| panic!("{}: {e}", entry.display()));
    assert!(
        report.parse_failures.is_empty(),
        "{}: fixture does not parse: {:?}",
        entry.display(),
        report.parse_failures
    );
    let expected = markers(entry);
    if expect_none {
        assert!(
            expected.is_empty(),
            "{}: safe fixtures must not contain markers",
            entry.display()
        );
    }
    let actual: BTreeSet<Key> = report
        .findings
        .iter()
        .map(|f| (f.file.clone(), f.span.line, f.rule.code().to_string()))
        .collect();
    tally.entries += 1;
    tally.expected += expected.len();
    for key in &actual {
        if expected.contains(key) {
            tally.true_positives += 1;
        } else {
            let message = report
                .findings
                .iter()
                .find(|f| f.file == key.0 && f.span.line == key.1 && f.rule.code() == key.2)
                .map(|f| f.message.clone())
                .unwrap_or_default();
            tally
                .false_positives
                .push(format!("{}:{} {} — {message}", key.0, key.1, key.2));
        }
    }
    for key in expected.difference(&actual) {
        tally
            .false_negatives
            .push(format!("{}:{} {}", key.0, key.1, key.2));
    }
}

fn entries(dir: &Path) -> Vec<PathBuf> {
    let Ok(read) = std::fs::read_dir(dir) else {
        return Vec::new();
    };
    let mut out: Vec<PathBuf> = read
        .flatten()
        .map(|e| e.path())
        .filter(|p| {
            p.is_dir()
                || matches!(
                    p.extension().and_then(|x| x.to_str()),
                    Some("luau") | Some("lua")
                )
        })
        .collect();
    out.sort();
    out
}

#[test]
fn corpus() {
    let root = Path::new("tests/fixtures");
    let mut rule_dirs: Vec<PathBuf> = std::fs::read_dir(root)
        .unwrap()
        .flatten()
        .map(|e| e.path())
        .filter(|p| p.is_dir())
        .collect();
    rule_dirs.sort();

    let mut table: BTreeMap<String, (Tally, Tally)> = BTreeMap::new();
    for dir in &rule_dirs {
        let name = dir.file_name().unwrap().to_string_lossy().to_string();
        let mut vulnerable = Tally::default();
        let mut safe = Tally::default();
        if name == "limitations" {
            for entry in entries(dir) {
                run_entry(&entry, &mut vulnerable, false);
            }
        } else {
            for entry in entries(&dir.join("vulnerable")) {
                run_entry(&entry, &mut vulnerable, false);
            }
            for entry in entries(&dir.join("safe")) {
                run_entry(&entry, &mut safe, true);
            }
        }
        table.insert(name, (vulnerable, safe));
    }

    let mut markdown = String::from(
        "| Corpus | Vulnerable entries | Safe entries | Expected findings | Found | False positives | False negatives |\n|---|---:|---:|---:|---:|---:|---:|\n",
    );
    let mut failures = Vec::new();
    let (mut total_fp, mut total_fn) = (0, 0);
    for (name, (vulnerable, safe)) in &table {
        let fp = vulnerable.false_positives.len() + safe.false_positives.len();
        let fns = vulnerable.false_negatives.len() + safe.false_negatives.len();
        markdown.push_str(&format!(
            "| {name} | {} | {} | {} | {} | {fp} | {fns} |\n",
            vulnerable.entries,
            safe.entries,
            vulnerable.expected + safe.expected,
            vulnerable.true_positives + safe.true_positives,
        ));
        let mut details = Vec::new();
        for t in [vulnerable, safe] {
            for fp in &t.false_positives {
                details.push(format!("  false positive: {fp}"));
            }
            for f in &t.false_negatives {
                details.push(format!("  false negative: {f}"));
            }
        }
        if !details.is_empty() {
            println!("{name}:\n{}", details.join("\n"));
        }
        if name != "limitations" {
            total_fp += fp;
            total_fn += fns;
            if !details.is_empty() {
                failures.push(format!("{name}:\n{}", details.join("\n")));
            }
        }
    }
    println!("\n{markdown}");
    println!(
        "total (excluding limitations): {total_fp} false positives, {total_fn} false negatives"
    );
    if let Ok(path) = std::env::var("LUAU_SHIELD_CORPUS_REPORT") {
        std::fs::write(path, &markdown).unwrap();
    }
    assert!(
        failures.is_empty(),
        "corpus mismatches:\n{}",
        failures.join("\n")
    );
}
