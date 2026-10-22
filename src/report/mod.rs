//! Output formats.

pub mod json;
pub mod sarif;
pub mod text;

use crate::Report;
use crate::rules::Severity;
use std::str::FromStr;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Format {
    Text,
    Json,
    Sarif,
}

impl FromStr for Format {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_ascii_lowercase().as_str() {
            "text" | "pretty" => Ok(Format::Text),
            "json" => Ok(Format::Json),
            "sarif" => Ok(Format::Sarif),
            other => Err(format!(
                "unknown format `{other}` (expected text, json or sarif)"
            )),
        }
    }
}

/// Counts of findings per severity, most severe first.
pub fn severity_counts(report: &Report) -> Vec<(Severity, usize)> {
    [
        Severity::Critical,
        Severity::High,
        Severity::Medium,
        Severity::Low,
        Severity::Info,
    ]
    .into_iter()
    .map(|s| {
        (
            s,
            report.findings.iter().filter(|f| f.severity == s).count(),
        )
    })
    .collect()
}

/// Stable 64-bit FNV-1a hash, used for SARIF fingerprints.
pub fn fingerprint(parts: &[&str]) -> String {
    let mut hash: u64 = 0xcbf29ce484222325;
    for part in parts {
        for b in part.bytes().chain(std::iter::once(0)) {
            hash ^= b as u64;
            hash = hash.wrapping_mul(0x100000001b3);
        }
    }
    format!("{hash:016x}")
}
