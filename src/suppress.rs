//! Inline suppressions:
//!
//! ```lua
//! coins.Value += amount -- luau-shield-ignore: LS001 validated by the shop module
//! -- luau-shield-ignore: LS003 doors are re-checked by DoorService
//! door:Destroy()
//! -- luau-shield-ignore-file: LS007 this remote is rate limited by the gateway
//! ```

use crate::rules::RuleId;
use full_moon::ast::Ast;
use full_moon::tokenizer::{Token, TokenType};
use full_moon::visitors::Visitor;
use std::collections::{HashMap, HashSet};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Suppression {
    /// `None` means every rule.
    pub rules: Option<Vec<RuleId>>,
    pub reason: String,
}

impl Suppression {
    fn covers(&self, rule: RuleId) -> bool {
        self.rules
            .as_ref()
            .is_none_or(|rules| rules.contains(&rule))
    }
}

#[derive(Clone, Debug, Default)]
pub struct Suppressions {
    /// Suppressions keyed by the line they apply to.
    lines: HashMap<usize, Vec<Suppression>>,
    file: Vec<Suppression>,
    /// Comments that look like suppressions but could not be understood.
    pub malformed: Vec<(usize, String)>,
}

#[derive(Default)]
struct Collector {
    comments: Vec<(usize, String)>,
    code_lines: HashSet<usize>,
}

impl Visitor for Collector {
    fn visit_token(&mut self, token: &Token) {
        match token.token_type() {
            TokenType::SingleLineComment { comment } => {
                self.comments
                    .push((token.start_position().line(), comment.to_string()));
            }
            TokenType::MultiLineComment { .. }
            | TokenType::Whitespace { .. }
            | TokenType::Shebang { .. }
            | TokenType::Eof => {}
            _ => {
                self.code_lines.insert(token.start_position().line());
            }
        }
    }
}

/// Parses the text after `--`. Returns `Some((file_level, suppression))` for
/// suppression comments, `Some(Err)` for malformed ones.
fn parse_comment(comment: &str) -> Option<Result<(bool, Suppression), String>> {
    let text = comment.trim();
    let (file_level, rest) = match text.strip_prefix("luau-shield-ignore-file") {
        Some(rest) => (true, rest),
        None => (false, text.strip_prefix("luau-shield-ignore")?),
    };
    let rest = rest.trim_start();
    let Some(rest) = rest.strip_prefix(':') else {
        if rest.is_empty() {
            return Some(Ok((
                file_level,
                Suppression {
                    rules: None,
                    reason: String::new(),
                },
            )));
        }
        return Some(Err(format!(
            "expected `:` after `luau-shield-ignore`, found `{rest}`"
        )));
    };
    let mut rules = Vec::new();
    let mut remaining = rest.trim_start();
    loop {
        let end = remaining
            .find(|c: char| !c.is_ascii_alphanumeric() && c != '-')
            .unwrap_or(remaining.len());
        let word = &remaining[..end];
        match word.parse::<RuleId>() {
            Ok(rule) if !word.is_empty() => {
                rules.push(rule);
                remaining = remaining[end..].trim_start();
                if let Some(after) = remaining.strip_prefix(',') {
                    remaining = after.trim_start();
                    continue;
                }
                break;
            }
            _ => break,
        }
    }
    if rules.is_empty() {
        return Some(Err(format!(
            "no rule code after `luau-shield-ignore:` in `{}`",
            comment.trim()
        )));
    }
    Some(Ok((
        file_level,
        Suppression {
            rules: Some(rules),
            reason: remaining.trim().to_string(),
        },
    )))
}

impl Suppressions {
    pub fn from_ast(ast: &Ast) -> Suppressions {
        let mut collector = Collector::default();
        collector.visit_ast(ast);
        let mut result = Suppressions::default();
        for (line, comment) in collector.comments {
            match parse_comment(&comment) {
                None => {}
                Some(Err(message)) => result.malformed.push((line, message)),
                Some(Ok((true, suppression))) => result.file.push(suppression),
                Some(Ok((false, suppression))) => {
                    // A comment on its own line applies to the next line of code.
                    let target = if collector.code_lines.contains(&line) {
                        line
                    } else {
                        (line + 1..line + 50)
                            .find(|l| collector.code_lines.contains(l))
                            .unwrap_or(line + 1)
                    };
                    result.lines.entry(target).or_default().push(suppression);
                }
            }
        }
        result
    }

    /// Is a finding of `rule` reported on `line` suppressed?
    pub fn is_suppressed(&self, rule: RuleId, line: usize) -> bool {
        self.file.iter().any(|s| s.covers(rule))
            || self
                .lines
                .get(&line)
                .is_some_and(|list| list.iter().any(|s| s.covers(rule)))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn suppressions(code: &str) -> Suppressions {
        let ast = full_moon::parse_fallible(code, full_moon::LuaVersion::luau()).into_ast();
        Suppressions::from_ast(&ast)
    }

    #[test]
    fn same_line_and_next_line() {
        let s = suppressions(
            "local a = 1 -- luau-shield-ignore: LS001 reason here\n\
             -- luau-shield-ignore: LS003, LS002 other reason\n\
             \n\
             local b = 2\n",
        );
        assert!(s.is_suppressed(RuleId::Ls001, 1));
        assert!(!s.is_suppressed(RuleId::Ls002, 1));
        assert!(s.is_suppressed(RuleId::Ls003, 4));
        assert!(s.is_suppressed(RuleId::Ls002, 4));
        assert!(!s.is_suppressed(RuleId::Ls001, 4));
    }

    #[test]
    fn file_level() {
        let s = suppressions("-- luau-shield-ignore-file: LS007 gateway limits it\nlocal x = 1\n");
        assert!(s.is_suppressed(RuleId::Ls007, 40));
        assert!(!s.is_suppressed(RuleId::Ls001, 2));
    }

    #[test]
    fn malformed() {
        let s = suppressions("local x = 1 -- luau-shield-ignore: because\n");
        assert_eq!(s.malformed.len(), 1);
        assert!(!s.is_suppressed(RuleId::Ls001, 1));
    }

    #[test]
    fn expect_markers_are_not_suppressions() {
        let s = suppressions("local x = 1 -- expect: LS001\n");
        assert!(s.malformed.is_empty());
        assert!(!s.is_suppressed(RuleId::Ls001, 1));
    }
}
