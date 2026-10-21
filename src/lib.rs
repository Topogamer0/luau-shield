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
}

impl Report {
    /// Should the process fail, given the `fail-on` threshold?
    pub fn fails(&self, config: &Config) -> bool {
        match config.fail_on {
            Some(threshold) => self.findings.iter().any(|f| f.severity >= threshold),
            None => false,
        }
    }
}

/// Analyses `paths` with `config`.
pub fn check(paths: &[PathBuf], config: &Config) -> Result<Report, String> {
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
            .collect(),
        warnings,
        sources,
    })
}
