//! SARIF 2.1.0 output (GitHub code scanning).

use super::fingerprint;
use crate::Report;
use crate::finding::Finding;
use crate::rules::{RULES, RuleId};
use serde_json::{Value, json};

fn location(file: &str, line: usize, column: usize, end_line: usize, end_column: usize) -> Value {
    let mut region = json!({ "startLine": line.max(1), "startColumn": column.max(1) });
    if end_line >= line && end_line > 0 {
        region["endLine"] = json!(end_line);
        if end_column > 0 && (end_line > line || end_column > column) {
            region["endColumn"] = json!(end_column);
        }
    }
    json!({
        "physicalLocation": {
            "artifactLocation": artifact(file),
            "region": region,
        }
    })
}

/// Percent-encodes a path for a URI (keeping `/`).
fn encode(path: &str) -> String {
    let mut out = String::new();
    for b in path.bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' | b'/' => {
                out.push(b as char)
            }
            _ => out.push_str(&format!("%{b:02X}")),
        }
    }
    out
}

/// Relative paths are relative to the source root; absolute paths (files
/// outside the working directory) become `file://` URIs.
fn artifact(file: &str) -> Value {
    let windows_drive = file.len() > 2 && file.as_bytes()[1] == b':';
    if file.starts_with('/') || windows_drive {
        let path = if windows_drive {
            format!("/{file}")
        } else {
            file.to_string()
        };
        json!({ "uri": format!("file://{}", encode(&path).replace("%3A", ":")) })
    } else {
        json!({ "uri": encode(file), "uriBaseId": "%SRCROOT%" })
    }
}

fn result(finding: &Finding) -> Value {
    let rule_index = RuleId::ALL
        .iter()
        .position(|r| *r == finding.rule)
        .unwrap_or(0);
    let mut message = finding.message.clone();
    if !message.ends_with('.') {
        message.push('.');
    }
    message.push(' ');
    message.push_str(&finding.fix);
    let mut value = json!({
        "ruleId": finding.rule.code(),
        "ruleIndex": rule_index,
        "level": finding.severity.sarif_level(),
        "message": { "text": message },
        "locations": [location(
            &finding.file,
            finding.span.line,
            finding.span.column,
            finding.span.end_line,
            finding.span.end_column,
        )],
        "partialFingerprints": {
            // Stable across message rewording and line moves: rule, file and the code itself.
            "luauShield/v1": fingerprint(&[finding.rule.code(), &finding.file, finding.snippet.trim()]),
        },
        "properties": { "severity": finding.severity.as_str() },
    });
    if finding.flow.len() > 1 {
        let steps: Vec<Value> = finding
            .flow
            .iter()
            .map(|step| {
                let mut loc = location(&step.file, step.line, step.column, 0, 0);
                loc["message"] = json!({ "text": step.note });
                json!({ "location": loc })
            })
            .collect();
        value["codeFlows"] = json!([{ "threadFlows": [{ "locations": steps }] }]);
    }
    value
}

pub fn render(report: &Report) -> String {
    let rules: Vec<Value> = RULES
        .iter()
        .zip(RuleId::ALL)
        .map(|(meta, rule)| {
            // Severity overrides from luau-shield.toml apply to the alerts.
            let severity = report.rule_severities.get(&rule).copied().unwrap_or(meta.severity);
            json!({
                "id": meta.code,
                "name": meta.slug,
                "shortDescription": { "text": meta.title },
                "fullDescription": { "text": meta.summary },
                "help": {
                    "text": format!("{}\n\nWhy: {}\n\nFix: {}", meta.summary, meta.why, meta.fix),
                    "markdown": format!("{}\n\n**Why:** {}\n\n**Fix:** {}\n\n[Documentation]({})", meta.summary, meta.why, meta.fix, meta.help_uri()),
                },
                "helpUri": meta.help_uri(),
                "defaultConfiguration": { "level": severity.sarif_level() },
                "properties": {
                    "tags": ["security", "roblox", "luau"],
                    "precision": "high",
                    "security-severity": severity.security_score(),
                },
            })
        })
        .collect();
    let notifications: Vec<Value> = report
        .parse_failures
        .iter()
        .map(|p| {
            json!({
                "level": "warning",
                "message": { "text": format!("could not parse the file: {}", p.message) },
                "locations": [location(&p.file, p.line, p.column, 0, 0)],
            })
        })
        .collect();
    let document = json!({
        "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
        "version": "2.1.0",
        "runs": [{
            "tool": {
                "driver": {
                    "name": "luau-shield",
                    "version": env!("CARGO_PKG_VERSION"),
                    "semanticVersion": env!("CARGO_PKG_VERSION"),
                    "informationUri": "https://github.com/Topogamer0/luau-shield",
                    "rules": rules,
                }
            },
            // Columns count characters, not UTF-16 code units.
            "columnKind": "unicodeCodePoints",
            "invocations": [{
                "executionSuccessful": true,
                "toolExecutionNotifications": notifications,
            }],
            "results": report.findings.iter().map(result).collect::<Vec<_>>(),
        }],
    });
    let mut text = serde_json::to_string_pretty(&document).expect("SARIF serializes");
    text.push('\n');
    text
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn uris() {
        assert_eq!(
            artifact("src/My Game/a.luau")["uri"],
            "src/My%20Game/a.luau"
        );
        assert_eq!(artifact("src/a.luau")["uriBaseId"], "%SRCROOT%");
        assert_eq!(artifact("/tmp/x y.luau")["uri"], "file:///tmp/x%20y.luau");
        assert_eq!(artifact("C:/work/a.luau")["uri"], "file:///C:/work/a.luau");
        assert!(artifact("/tmp/a.luau").get("uriBaseId").is_none());
    }
}
