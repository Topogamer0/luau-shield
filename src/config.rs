//! `luau-shield.toml` loading and the resolved configuration used by the
//! analyzer.

use crate::analysis::value::{Checks, checks_from_names};
use crate::rules::{RuleId, Severity};
use globset::{Glob, GlobSet, GlobSetBuilder};
use serde::Deserialize;
use std::collections::{BTreeMap, HashMap};
use std::path::{Path, PathBuf};

pub const CONFIG_FILE_NAME: &str = "luau-shield.toml";

#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "kebab-case", deny_unknown_fields)]
struct RawConfig {
    min_severity: Option<String>,
    fail_on: Option<String>,
    project: Option<PathBuf>,
    #[serde(default)]
    ignore: Vec<String>,
    trust_unresolved_validators: Option<bool>,
    max_call_depth: Option<usize>,
    #[serde(default)]
    rules: BTreeMap<String, RawRuleSetting>,
    #[serde(default)]
    sanitizers: Vec<RawSanitizer>,
    #[serde(default)]
    sinks: Vec<RawSink>,
    #[serde(default)]
    sources: Vec<RawSource>,
    #[serde(default)]
    explain: RawExplain,
}

#[derive(Debug, Deserialize)]
#[serde(untagged)]
enum RawRuleSetting {
    Text(String),
    Bool(bool),
    Table {
        enabled: Option<bool>,
        severity: Option<String>,
    },
}

#[derive(Debug, Deserialize)]
#[serde(untagged)]
enum RawChecks {
    Text(String),
    List(Vec<String>),
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "kebab-case", deny_unknown_fields)]
struct RawSanitizer {
    function: String,
    checks: Option<RawChecks>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "kebab-case", deny_unknown_fields)]
struct RawSink {
    function: String,
    rule: String,
    arguments: Option<Vec<usize>>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "kebab-case", deny_unknown_fields)]
struct RawSource {
    function: String,
    trusted_parameters: Option<usize>,
}

#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "kebab-case", deny_unknown_fields)]
struct RawExplain {
    model: Option<String>,
    timeout_seconds: Option<u64>,
}

/// A dotted function name pattern: `Validate.amount`, `*.Client.*`.
/// `:` and `.` are equivalent, `*` matches exactly one segment.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct NamePattern {
    segments: Vec<String>,
}

impl NamePattern {
    pub fn new(pattern: &str) -> NamePattern {
        NamePattern {
            segments: pattern
                .split(['.', ':'])
                .map(|s| s.trim().to_string())
                .filter(|s| !s.is_empty())
                .collect(),
        }
    }

    pub fn matches(&self, path: &[String]) -> bool {
        self.segments.len() == path.len()
            && self
                .segments
                .iter()
                .zip(path)
                .all(|(pattern, name)| pattern == "*" || pattern == name)
    }
}

#[derive(Clone, Debug)]
pub struct Sanitizer {
    pub pattern: NamePattern,
    pub checks: Checks,
}

#[derive(Clone, Debug)]
pub struct CustomSink {
    pub pattern: NamePattern,
    pub rule: RuleId,
    /// 1-based argument positions, `None` = all.
    pub arguments: Option<Vec<usize>>,
}

#[derive(Clone, Debug)]
pub struct CustomSource {
    pub pattern: NamePattern,
    pub trusted_parameters: usize,
}

#[derive(Clone, Copy, Debug)]
pub struct RuleSetting {
    pub enabled: bool,
    pub severity: Severity,
}

#[derive(Clone, Debug)]
pub struct Config {
    pub min_severity: Severity,
    /// `None` = never fail.
    pub fail_on: Option<Severity>,
    pub project: Option<PathBuf>,
    pub ignore: GlobSet,
    /// Directory the ignore globs (and `project`) are relative to.
    pub base_dir: PathBuf,
    pub trust_unresolved_validators: bool,
    pub max_call_depth: usize,
    pub rules: HashMap<RuleId, RuleSetting>,
    pub sanitizers: Vec<Sanitizer>,
    pub sinks: Vec<CustomSink>,
    pub sources: Vec<CustomSource>,
    pub explain_model: String,
    pub explain_timeout_seconds: u64,
    /// Where the configuration was loaded from, if anywhere.
    pub source_file: Option<PathBuf>,
}

impl Default for Config {
    fn default() -> Self {
        Config {
            min_severity: Severity::Low,
            fail_on: Some(Severity::Low),
            project: None,
            ignore: GlobSet::empty(),
            base_dir: PathBuf::from("."),
            trust_unresolved_validators: true,
            max_call_depth: 6,
            rules: RuleId::ALL
                .into_iter()
                .map(|rule| {
                    (
                        rule,
                        RuleSetting {
                            enabled: true,
                            severity: rule.meta().severity,
                        },
                    )
                })
                .collect(),
            sanitizers: Vec::new(),
            sinks: Vec::new(),
            sources: vec![CustomSource {
                // Knit services: `function Service.Client:Method(player, ...)`.
                pattern: NamePattern::new("*.Client.*"),
                trusted_parameters: 1,
            }],
            explain_model: "qwen2.5-coder:7b".to_string(),
            explain_timeout_seconds: 60,
            source_file: None,
        }
    }
}

pub fn parse_fail_on(text: &str) -> Result<Option<Severity>, String> {
    if text.eq_ignore_ascii_case("never") || text.eq_ignore_ascii_case("none") {
        Ok(None)
    } else {
        text.parse::<Severity>()
            .map(Some)
            .map_err(|e| format!("{e} or never"))
    }
}

impl Config {
    /// Finds `luau-shield.toml` in `start` (or its directory) or any ancestor.
    pub fn discover(start: &Path) -> Option<PathBuf> {
        let start = if start.is_file() {
            start.parent()?.to_path_buf()
        } else {
            start.to_path_buf()
        };
        let start = if start.is_absolute() {
            start
        } else {
            std::env::current_dir().ok()?.join(start)
        };
        let mut dir = Some(start.as_path());
        while let Some(d) = dir {
            let candidate = d.join(CONFIG_FILE_NAME);
            if candidate.is_file() {
                return Some(candidate);
            }
            dir = d.parent();
        }
        None
    }

    pub fn load(path: &Path) -> Result<Config, String> {
        let text = std::fs::read_to_string(path)
            .map_err(|e| format!("cannot read {}: {e}", path.display()))?;
        let base = path.parent().unwrap_or(Path::new(".")).to_path_buf();
        let mut config =
            Config::from_toml(&text, &base).map_err(|e| format!("{}: {e}", path.display()))?;
        config.source_file = Some(path.to_path_buf());
        Ok(config)
    }

    pub fn from_toml(text: &str, base_dir: &Path) -> Result<Config, String> {
        let raw: RawConfig = toml::from_str(text).map_err(|e| e.to_string())?;
        let mut config = Config {
            base_dir: base_dir.to_path_buf(),
            ..Config::default()
        };
        if let Some(s) = raw.min_severity {
            config.min_severity = s.parse()?;
        }
        if let Some(s) = raw.fail_on {
            config.fail_on = parse_fail_on(&s)?;
        }
        config.project = raw.project.map(|p| base_dir.join(p));
        let mut globs = GlobSetBuilder::new();
        for pattern in &raw.ignore {
            let glob =
                Glob::new(pattern).map_err(|e| format!("invalid ignore glob `{pattern}`: {e}"))?;
            globs.add(glob);
            // `dir/` or `dir` should also ignore everything inside it.
            if !pattern.ends_with("**") {
                let nested = format!("{}/**", pattern.trim_end_matches('/'));
                if let Ok(glob) = Glob::new(&nested) {
                    globs.add(glob);
                }
            }
        }
        config.ignore = globs.build().map_err(|e| e.to_string())?;
        if let Some(v) = raw.trust_unresolved_validators {
            config.trust_unresolved_validators = v;
        }
        if let Some(depth) = raw.max_call_depth {
            config.max_call_depth = depth.clamp(1, 32);
        }
        for (name, setting) in raw.rules {
            let rule: RuleId = name.parse()?;
            let entry = config
                .rules
                .get_mut(&rule)
                .expect("every rule has a setting");
            match setting {
                RawRuleSetting::Bool(enabled) => entry.enabled = enabled,
                RawRuleSetting::Text(text) => match text.to_ascii_lowercase().as_str() {
                    "off" | "false" | "disabled" => entry.enabled = false,
                    "on" | "true" | "enabled" => entry.enabled = true,
                    other => {
                        entry.severity = other
                            .parse()
                            .map_err(|e| format!("rules.{name}: {e}, on or off"))?;
                        entry.enabled = true;
                    }
                },
                RawRuleSetting::Table { enabled, severity } => {
                    if let Some(enabled) = enabled {
                        entry.enabled = enabled;
                    }
                    if let Some(severity) = severity {
                        entry.severity =
                            severity.parse().map_err(|e| format!("rules.{name}: {e}"))?;
                    }
                }
            }
        }
        for sanitizer in raw.sanitizers {
            let checks = match sanitizer.checks {
                None => checks_from_names(&["all"])?,
                Some(RawChecks::Text(text)) => checks_from_names(&[text.as_str()])?,
                Some(RawChecks::List(list)) => {
                    let names: Vec<&str> = list.iter().map(String::as_str).collect();
                    checks_from_names(&names)?
                }
            };
            config.sanitizers.push(Sanitizer {
                pattern: NamePattern::new(&sanitizer.function),
                checks,
            });
        }
        for sink in raw.sinks {
            let rule: RuleId = sink.rule.parse()?;
            if let Some(args) = &sink.arguments {
                if args.contains(&0) {
                    return Err(format!(
                        "sinks `{}`: argument positions are 1-based",
                        sink.function
                    ));
                }
            }
            config.sinks.push(CustomSink {
                pattern: NamePattern::new(&sink.function),
                rule,
                arguments: sink.arguments,
            });
        }
        for source in raw.sources {
            config.sources.push(CustomSource {
                pattern: NamePattern::new(&source.function),
                trusted_parameters: source.trusted_parameters.unwrap_or(1),
            });
        }
        if let Some(model) = raw.explain.model {
            config.explain_model = model;
        }
        if let Some(timeout) = raw.explain.timeout_seconds {
            config.explain_timeout_seconds = timeout.max(1);
        }
        Ok(config)
    }

    pub fn rule_enabled(&self, rule: RuleId) -> bool {
        self.rules.get(&rule).is_none_or(|s| s.enabled)
    }

    pub fn severity_of(&self, rule: RuleId) -> Severity {
        self.rules
            .get(&rule)
            .map(|s| s.severity)
            .unwrap_or(rule.meta().severity)
    }
}

/// The starter configuration written by `luau-shield init`.
pub const STARTER_CONFIG: &str = include_str!("../luau-shield.example.toml");

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_full_config() {
        let config = Config::from_toml(
            r#"
            min-severity = "medium"
            fail-on = "never"
            ignore = ["vendor"]
            [rules]
            LS007 = "off"
            LS006 = "high"
            LS002 = { enabled = true, severity = "low" }
            [[sanitizers]]
            function = "Validate.amount"
            [[sanitizers]]
            function = "Guard:owns"
            checks = ["ownership"]
            [[sinks]]
            function = "Economy.addCoins"
            rule = "LS001"
            arguments = [2]
            [[sources]]
            function = "Net.*"
            trusted-parameters = 1
            [explain]
            model = "llama3.1"
            "#,
            Path::new("."),
        )
        .unwrap();
        assert_eq!(config.min_severity, Severity::Medium);
        assert_eq!(config.fail_on, None);
        assert!(!config.rule_enabled(RuleId::Ls007));
        assert_eq!(config.severity_of(RuleId::Ls006), Severity::High);
        assert_eq!(config.severity_of(RuleId::Ls002), Severity::Low);
        assert_eq!(config.sanitizers.len(), 2);
        assert!(config.ignore.is_match("vendor/x.luau"));
        assert_eq!(config.sources.len(), 2);
        assert_eq!(config.explain_model, "llama3.1");
    }

    #[test]
    fn rejects_unknown_keys() {
        assert!(Config::from_toml("bogus = 1", Path::new(".")).is_err());
        assert!(Config::from_toml("[rules]\nLS999 = \"off\"", Path::new(".")).is_err());
    }

    #[test]
    fn starter_config_is_valid() {
        Config::from_toml(STARTER_CONFIG, Path::new(".")).unwrap();
    }

    #[test]
    fn name_patterns() {
        let p = NamePattern::new("*.Client.*");
        assert!(p.matches(&["Shop".into(), "Client".into(), "Buy".into()]));
        assert!(!p.matches(&["Shop".into(), "Buy".into()]));
        assert!(NamePattern::new("Guard:owns").matches(&["Guard".into(), "owns".into()]));
    }
}
