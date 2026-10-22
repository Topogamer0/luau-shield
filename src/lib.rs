//! luau-shield: static taint analysis for Roblox games written in Luau.
//!
//! The library entry point is [`check`]: it loads the files, runs the
//! analysis and returns a [`Report`].

pub mod analysis;
pub mod config;
pub mod explain;
pub mod finding;
pub mod project;
pub mod report;
pub mod rules;
pub mod suppress;

use config::Config;
use finding::{Finding, ParseFailure};
use project::{LoadOptions, Project};
use std::collections::BTreeMap;
use std::path::PathBuf;

/// Result of a check.
#[derive(Debug, Default)]
pub struct Report {
    /// Findings at or above the configured minimum severity, sorted.
    pub findings: Vec<Finding>,
    /// Findings silenced by inline suppression comments.
    pub suppressed: usize,
    /// Findings hidden because they are below the minimum severity.
    pub below_threshold: usize,
    pub files_scanned: usize,
    pub parse_failures: Vec<ParseFailure>,
    pub warnings: Vec<String>,
    /// Source text of the files that have findings, by display path.
    pub sources: BTreeMap<String, String>,
    /// Effective severity of every rule (after configuration overrides).
    pub rule_severities: BTreeMap<rules::RuleId, rules::Severity>,
}

impl Report {
    /// Should the process fail, given the `fail-on` threshold?
    pub fn fails(&self, config: &Config) -> bool {
        match config.fail_on {
            Some(threshold) => self.findings.iter().any(|f| f.severity >= threshold),
            None => false,
        }
    }

    /// Files were skipped because they could not be read or parsed, and the
    /// configuration does not allow it.
    pub fn incomplete(&self, config: &Config) -> bool {
        !self.parse_failures.is_empty() && !config.allow_parse_errors
    }
}

/// Analyses `paths` with `config`.
///
/// The analysis runs on a thread with a large stack: deeply nested code is
/// interpreted recursively.
pub fn check(paths: &[PathBuf], config: &Config) -> Result<Report, String> {
    let paths = paths.to_vec();
    let config = config.clone();
    std::thread::Builder::new()
        .name("luau-shield".into())
        .stack_size(512 * 1024 * 1024)
        .spawn(move || check_on_this_thread(&paths, &config))
        .map_err(|e| format!("cannot start the analysis thread: {e}"))?
        .join()
        .map_err(|_| "internal error during the analysis".to_string())?
}

fn check_on_this_thread(paths: &[PathBuf], config: &Config) -> Result<Report, String> {
    let project = Project::load(
        paths,
        &LoadOptions {
            ignore: config.ignore.clone(),
            ignore_base: config.base_dir.clone(),
            project_file: config.project.clone(),
        },
    )?;
    let output = analysis::analyze(&project, config);
    let mut warnings = project.warnings.clone();
    warnings.extend(output.warnings);
    for file in &project.files {
        for (line, message) in &file.suppressions.malformed {
            warnings.push(format!(
                "{}:{line}: ignored suppression comment: {message}",
                file.rel
            ));
        }
    }
    let total = output.findings.len();
    let mut findings: Vec<Finding> = output
        .findings
        .into_iter()
        .filter(|f| f.severity >= config.min_severity)
        .collect();
    findings.sort_by_key(Finding::sort_key);
    let below_threshold = total - findings.len();
    let mut sources = BTreeMap::new();
    for finding in &mut findings {
        let file = &project.files[finding.file_id];
        finding.snippet = file.line(finding.span.line).trim_end().to_string();
        sources
            .entry(file.rel.clone())
            .or_insert_with(|| file.text.clone());
        for step in &finding.flow {
            if let Some(other) = project.files.iter().find(|f| f.rel == step.file) {
                sources
                    .entry(other.rel.clone())
                    .or_insert_with(|| other.text.clone());
            }
        }
    }
    Ok(Report {
        findings,
        suppressed: output.suppressed,
        below_threshold,
        files_scanned: project.files.len(),
        parse_failures: project
            .files
            .iter()
            .filter_map(|f| f.parse_error.clone())
            .chain(project.unreadable.iter().cloned())
            .collect(),
        rule_severities: rules::RuleId::ALL
            .into_iter()
            .map(|rule| (rule, config.severity_of(rule)))
            .collect(),
        warnings,
        sources,
    })
}
