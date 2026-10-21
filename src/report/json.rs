//! Machine-readable JSON output.

use super::severity_counts;
use crate::Report;
use serde_json::{Value, json};

pub fn render(report: &Report) -> String {
    let by_severity: serde_json::Map<String, Value> = severity_counts(report)
        .into_iter()
        .map(|(s, n)| (s.to_string(), json!(n)))
        .collect();
    let findings: Vec<Value> = report
        .findings
        .iter()
        .map(|f| {
            let mut value = serde_json::to_value(f).expect("findings serialize");
            if let Some(object) = value.as_object_mut() {
                object.insert("help_uri".into(), json!(f.rule.meta().help_uri()));
                object.insert("slug".into(), json!(f.rule.meta().slug));
            }
            value
        })
        .collect();
    let document = json!({
        "tool": "luau-shield",
        "version": env!("CARGO_PKG_VERSION"),
        "summary": {
            "files": report.files_scanned,
            "findings": report.findings.len(),
            "by_severity": by_severity,
            "suppressed": report.suppressed,
            "below_threshold": report.below_threshold,
            "parse_errors": report.parse_failures.len(),
        },
        "findings": findings,
        "parse_errors": report.parse_failures,
        "warnings": report.warnings,
    });
    let mut text = serde_json::to_string_pretty(&document).expect("report serializes");
    text.push('\n');
    text
}
