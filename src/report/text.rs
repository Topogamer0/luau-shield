//! Human-readable output with source excerpts.

use super::severity_counts;
use crate::Report;
use crate::finding::Finding;
use crate::rules::Severity;
use anstyle::{AnsiColor, Effects, Style};
use std::fmt::Write;

struct Palette {
    enabled: bool,
}

impl Palette {
    fn paint(&self, style: Style, text: &str) -> String {
        if self.enabled {
            format!("{}{text}{}", style.render(), style.render_reset())
        } else {
            text.to_string()
        }
    }

    fn severity(&self, severity: Severity) -> Style {
        let color = match severity {
            Severity::Critical => AnsiColor::Magenta,
            Severity::High => AnsiColor::Red,
            Severity::Medium => AnsiColor::Yellow,
            Severity::Low => AnsiColor::Cyan,
            Severity::Info => AnsiColor::BrightBlack,
        };
        Style::new()
            .fg_color(Some(color.into()))
            .effects(Effects::BOLD)
    }

    fn gutter(&self) -> Style {
        Style::new()
            .fg_color(Some(AnsiColor::Blue.into()))
            .effects(Effects::BOLD)
    }

    fn bold(&self) -> Style {
        Style::new().effects(Effects::BOLD)
    }

    fn dim(&self) -> Style {
        Style::new().effects(Effects::DIMMED)
    }
}

/// Wraps `text` to `width` columns, prefixing continuation lines.
fn wrap(text: &str, width: usize, indent: &str) -> String {
    let mut out = String::new();
    let mut line_len = 0;
    for word in text.split_whitespace() {
        if line_len > 0 && line_len + 1 + word.chars().count() > width {
            out.push('\n');
            out.push_str(indent);
            line_len = 0;
        } else if line_len > 0 {
            out.push(' ');
            line_len += 1;
        }
        out.push_str(word);
        line_len += word.chars().count();
    }
    out
}

fn render_finding(out: &mut String, finding: &Finding, report: &Report, p: &Palette) {
    let label = format!("{}[{}]", finding.severity, finding.rule);
    let _ = writeln!(
        out,
        "{}{} {}",
        p.paint(p.severity(finding.severity), &label),
        p.paint(p.bold(), ":"),
        p.paint(p.bold(), &finding.title)
    );
    let line = finding.span.line;
    let width = line.to_string().len().max(2);
    let pad = " ".repeat(width);
    let _ = writeln!(
        out,
        "{pad}{} {}:{}:{}",
        p.paint(p.gutter(), "-->"),
        finding.file,
        line,
        finding.span.column
    );
    let _ = writeln!(out, "{pad} {}", p.paint(p.gutter(), "|"));
    if let Some(source) = report.sources.get(&finding.file) {
        let lines: Vec<&str> = source.lines().collect();
        if line >= 2 {
            if let Some(previous) = lines.get(line - 2) {
                if !previous.trim().is_empty() {
                    let _ = writeln!(
                        out,
                        "{} {} {}",
                        p.paint(p.gutter(), &format!("{:>width$}", line - 1)),
                        p.paint(p.gutter(), "|"),
                        previous.replace('\t', "    ")
                    );
                }
            }
        }
        if let Some(text) = lines.get(line - 1) {
            let expanded = text.replace('\t', "    ");
            let _ = writeln!(
                out,
                "{} {} {}",
                p.paint(p.gutter(), &format!("{line:>width$}")),
                p.paint(p.gutter(), "|"),
                expanded
            );
            // Columns count characters; tabs were expanded to 4 spaces.
            let prefix: String = text
                .chars()
                .take(finding.span.column.saturating_sub(1))
                .collect();
            let start = prefix.replace('\t', "    ").chars().count();
            let end =
                if finding.span.end_line == line && finding.span.end_column > finding.span.column {
                    let upto: String = text
                        .chars()
                        .take(finding.span.end_column.saturating_sub(1))
                        .collect();
                    upto.replace('\t', "    ").chars().count()
                } else {
                    expanded.trim_end().chars().count()
                };
            let carets = "^".repeat(end.saturating_sub(start).max(1));
            let _ = writeln!(
                out,
                "{pad} {} {}{} {}",
                p.paint(p.gutter(), "|"),
                " ".repeat(start),
                p.paint(p.severity(finding.severity), &carets),
                p.paint(p.severity(finding.severity), &finding.message)
            );
        }
    }
    let _ = writeln!(out, "{pad} {}", p.paint(p.gutter(), "|"));
    if finding.flow.len() > 1 {
        let _ = writeln!(
            out,
            "{pad} {} {}",
            p.paint(p.gutter(), "="),
            p.paint(p.bold(), "data flow:")
        );
        for (i, step) in finding.flow.iter().enumerate() {
            let location = format!("{}:{}:{}", step.file, step.line, step.column);
            let _ = writeln!(out, "{pad}     {}. {}", i + 1, p.paint(p.dim(), &location),);
            let _ = writeln!(
                out,
                "{pad}        {}",
                wrap(&step.note, 88, &format!("{pad}        "))
            );
        }
    }
    let indent = format!("{pad}         ");
    let _ = writeln!(
        out,
        "{pad} {} {} {}",
        p.paint(p.gutter(), "="),
        p.paint(p.bold(), "why:"),
        wrap(&finding.why, 88, &indent)
    );
    let _ = writeln!(
        out,
        "{pad} {} {} {}",
        p.paint(p.gutter(), "="),
        p.paint(p.bold(), "fix:"),
        wrap(&finding.fix, 88, &indent)
    );
    let _ = writeln!(
        out,
        "{pad} {} {} https://github.com/Topogamer0/luau-shield/blob/main/docs/rules/{}.md",
        p.paint(p.gutter(), "="),
        p.paint(p.bold(), "docs:"),
        finding.rule
    );
    if let Some(explanation) = &finding.ai_explanation {
        let _ = writeln!(
            out,
            "{pad} {} {}",
            p.paint(p.gutter(), "="),
            p.paint(p.bold(), "explanation (local model, may be wrong):")
        );
        for l in explanation.lines() {
            let _ = writeln!(out, "{pad}     {l}");
        }
    }
    out.push('\n');
}

/// Renders the report. `quiet` prints only the summary.
pub fn render(report: &Report, color: bool, quiet: bool) -> String {
    let p = Palette { enabled: color };
    let mut out = String::new();
    if !quiet {
        for finding in &report.findings {
            render_finding(&mut out, finding, report, &p);
        }
    }
    let files = if report.files_scanned == 1 {
        "file"
    } else {
        "files"
    };
    if report.findings.is_empty() {
        let _ = write!(
            out,
            "{} No problems found in {} {files}.",
            p.paint(
                Style::new()
                    .fg_color(Some(AnsiColor::Green.into()))
                    .effects(Effects::BOLD),
                "✓"
            ),
            report.files_scanned
        );
    } else {
        let parts: Vec<String> = severity_counts(report)
            .into_iter()
            .filter(|(_, n)| *n > 0)
            .map(|(s, n)| p.paint(p.severity(s), &format!("{n} {s}")))
            .collect();
        let problems = if report.findings.len() == 1 {
            "problem"
        } else {
            "problems"
        };
        let _ = write!(
            out,
            "{} {} {problems} ({}) in {} {files}.",
            p.paint(p.bold(), "Found"),
            report.findings.len(),
            parts.join(", "),
            report.files_scanned
        );
    }
    if report.suppressed > 0 {
        let _ = write!(out, " {} suppressed by comments.", report.suppressed);
    }
    if report.below_threshold > 0 {
        let _ = write!(
            out,
            " {} below the minimum severity.",
            report.below_threshold
        );
    }
    if !report.parse_failures.is_empty() {
        let _ = write!(out, " {} could not be parsed.", report.parse_failures.len());
    }
    out.push('\n');
    out
}
