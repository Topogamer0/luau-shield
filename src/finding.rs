//! The result of an analysis: findings with their location and data flow.

use crate::rules::{RuleId, Severity};
use serde::Serialize;

/// A 1-based source position range.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize)]
pub struct Span {
    pub line: usize,
    pub column: usize,
    pub end_line: usize,
    pub end_column: usize,
}

/// A location inside one of the analysed files.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct Loc {
    pub file: usize,
    pub span: Span,
}

/// One step of the path followed by untrusted data.
#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct FlowStep {
    /// Path of the file, relative to the analysed root, with `/` separators.
    pub file: String,
    pub line: usize,
    pub column: usize,
    pub note: String,
}

#[derive(Clone, Debug, Serialize)]
pub struct Finding {
    pub rule: RuleId,
    pub severity: Severity,
    pub title: String,
    /// Path of the file, relative to the analysed root, with `/` separators.
    pub file: String,
    #[serde(flatten)]
    pub span: Span,
    /// What exactly happens at this location.
    pub message: String,
    /// The source line of the finding.
    pub snippet: String,
    /// The path followed by the data, from the source to the sink.
    pub flow: Vec<FlowStep>,
    /// Why this is exploitable.
    pub why: String,
    /// How to fix it.
    pub fix: String,
    /// Optional explanation produced by a local model (`--explain`).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ai_explanation: Option<String>,
    #[serde(skip)]
    pub file_id: usize,
}

impl Finding {
    /// Sort key giving a stable, readable order.
    pub fn sort_key(&self) -> (String, usize, usize, RuleId) {
        (
            self.file.clone(),
            self.span.line,
            self.span.column,
            self.rule,
        )
    }
}

/// A file that could not be parsed.
#[derive(Clone, Debug, Serialize)]
pub struct ParseFailure {
    pub file: String,
    pub line: usize,
    pub column: usize,
    pub message: String,
}
