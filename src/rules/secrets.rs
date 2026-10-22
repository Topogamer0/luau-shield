//! luau-shield008: secrets hard-coded in code whose source is sent to clients.

use crate::analysis::{compact, span_of, token_name};
use crate::finding::{Loc, Span};
use crate::rules::identifier_words;
use full_moon::ast::{
    Assignment, Expression, Field, Index, LocalAssignment, Suffix, TableConstructor, Var,
};
use full_moon::tokenizer::{Token, TokenType};
use full_moon::visitors::Visitor;
use regex::Regex;
use std::collections::BTreeMap;
use std::sync::OnceLock;

/// A detected secret.
pub struct SecretHit {
    pub loc: Loc,
    pub kind: &'static str,
    /// Redacted preview of the value.
    pub preview: String,
}

struct Pattern {
    kind: &'static str,
    regex: Regex,
}

fn patterns() -> &'static [Pattern] {
    static PATTERNS: OnceLock<Vec<Pattern>> = OnceLock::new();
    PATTERNS.get_or_init(|| {
        let raw: &[(&str, &str)] = &[
            (
                "Discord webhook URL",
                r"https?://(?:(?:canary|ptb)\.)?discord(?:app)?\.com/api(?:/v\d+)?/webhooks/\d{5,}/[A-Za-z0-9_\-]{20,}",
            ),
            (
                "Guilded webhook URL",
                r"https?://media\.guilded\.gg/webhooks/[0-9a-fA-F\-]{20,}/[A-Za-z0-9_\-]{20,}",
            ),
            (
                "Slack webhook URL",
                r"https://hooks\.slack\.com/services/[A-Z0-9]+/[A-Z0-9]+/[A-Za-z0-9]{16,}",
            ),
            ("Anthropic API key", r"\bsk-ant-[A-Za-z0-9_\-]{20,}"),
            ("OpenAI API key", r"\bsk-(?:proj-|svcacct-|admin-)?[A-Za-z0-9_\-]{20,}"),
            ("GitHub token", r"\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})"),
            ("AWS access key", r"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b"),
            ("Google API key", r"\bAIza[0-9A-Za-z_\-]{35}"),
            ("Stripe live key", r"\b(?:sk|rk)_live_[0-9A-Za-z]{20,}"),
            ("Telegram bot token", r"\b\d{8,10}:[A-Za-z0-9_\-]{35}\b"),
            (".ROBLOSECURITY cookie", r"_\|WARNING:-DO-NOT-SHARE-THIS\."),
            (
                "private key",
                r"-----BEGIN (?:RSA |EC |OPENSSH |DSA |PGP |ENCRYPTED )?PRIVATE KEY",
            ),
            (
                "JSON Web Token",
                r"\beyJ[A-Za-z0-9_\-]{10,}\.eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}",
            ),
            (
                "credential in a URL",
                r"[?&](?:api_?key|apikey|key|token|access_token|secret|password)=[A-Za-z0-9_\-]{16,}",
            ),
        ];
        raw.iter()
            .map(|(kind, re)| Pattern {
                kind,
                regex: Regex::new(re).expect("valid secret pattern"),
            })
            .collect()
    })
}

/// Placeholder values that are obviously not real secrets.
fn is_placeholder(value: &str) -> bool {
    let lower = value.to_ascii_lowercase();
    const MARKERS: &[&str] = &[
        "your",
        "here",
        "xxxx",
        "example",
        "placeholder",
        "insert",
        "changeme",
        "change_me",
        "todo",
        "fixme",
        "dummy",
        "<",
        "{",
        "replace",
        "redacted",
        "****",
    ];
    if MARKERS.iter().any(|m| lower.contains(m)) {
        return true;
    }
    let mut chars = value.chars();
    match chars.next() {
        Some(first) => chars.all(|c| c == first),
        None => true,
    }
}

/// Does a variable / field name suggest it holds a credential?
fn secret_name(name: &str) -> bool {
    let joined: String = name
        .chars()
        .filter(|c| c.is_alphanumeric())
        .collect::<String>()
        .to_ascii_lowercase();
    const JOINED: &[&str] = &[
        "apikey",
        "secret",
        "token",
        "password",
        "passwd",
        "webhook",
        "privatekey",
        "accesskey",
        "masterkey",
        "encryptionkey",
        "licensekey",
        "signingkey",
        "hmackey",
        "bearer",
        "credential",
        "cookie",
        "robloxsecurity",
    ];
    if JOINED.iter().any(|w| joined.contains(w)) {
        return true;
    }
    identifier_words(name)
        .iter()
        .any(|w| matches!(w.as_str(), "auth" | "authorization"))
}

/// A literal that looks like a credential (long, no spaces, mixed characters).
fn credential_like(value: &str) -> bool {
    let value = value
        .strip_prefix("Bearer ")
        .or_else(|| value.strip_prefix("Bot "))
        .or_else(|| value.strip_prefix("Basic "))
        .unwrap_or(value);
    if value.len() < 16 || value.contains(char::is_whitespace) || is_placeholder(value) {
        return false;
    }
    let letters = value.chars().any(|c| c.is_ascii_alphabetic());
    let digits = value.chars().any(|c| c.is_ascii_digit());
    letters && digits
}

fn redact(value: &str) -> String {
    let shown: String = value.chars().take(12).collect();
    if value.chars().count() > 12 {
        format!("{shown}…")
    } else {
        shown
    }
}

struct SecretVisitor {
    file: usize,
    hits: BTreeMap<(usize, usize), SecretHit>,
}

impl SecretVisitor {
    fn add(&mut self, span: Span, kind: &'static str, value: &str) {
        let hit = SecretHit {
            loc: Loc {
                file: self.file,
                span,
            },
            kind,
            preview: redact(value),
        };
        let key = (span.line, span.column);
        // A specific kind ("Discord webhook URL") beats the generic one.
        match self.hits.get(&key) {
            Some(existing) if existing.kind != "credential" || kind == "credential" => {}
            _ => {
                self.hits.insert(key, hit);
            }
        }
    }

    fn check_named(&mut self, name: &str, expr: &Expression) {
        if !secret_name(name) {
            return;
        }
        if let Expression::String(token) = expr {
            if let TokenType::StringLiteral { literal, .. } = token.token().token_type() {
                if credential_like(literal) {
                    self.add(span_of(token), "credential", literal);
                }
            }
        }
    }

    fn scan_text(&mut self, token: &Token, text: &str) {
        for pattern in patterns() {
            if pattern.kind == "OpenAI API key" && text.contains("sk-ant-") {
                continue;
            }
            if let Some(m) = pattern.regex.find(text) {
                if is_placeholder(m.as_str()) {
                    continue;
                }
                let start = token.start_position();
                let end = token.end_position();
                let span = Span {
                    line: start.line(),
                    column: start.character(),
                    end_line: end.line(),
                    end_column: end.character(),
                };
                self.add(span, pattern.kind, m.as_str());
                return;
            }
        }
    }
}

fn var_name(var: &Var) -> Option<String> {
    match var {
        Var::Name(token) => Some(token_name(token)),
        Var::Expression(expr) => match expr.suffixes().last() {
            Some(Suffix::Index(Index::Dot { name, .. })) => Some(token_name(name)),
            Some(Suffix::Index(Index::Brackets { expression, .. })) => match &**expression {
                Expression::String(token) => match token.token().token_type() {
                    TokenType::StringLiteral { literal, .. } => Some(literal.to_string()),
                    _ => None,
                },
                _ => None,
            },
            _ => None,
        },
        _ => Some(compact(var)),
    }
}

impl Visitor for SecretVisitor {
    fn visit_local_assignment(&mut self, node: &LocalAssignment) {
        for (name, expr) in node.names().iter().zip(node.expressions().iter()) {
            self.check_named(&token_name(name), expr);
        }
    }

    fn visit_assignment(&mut self, node: &Assignment) {
        for (var, expr) in node.variables().iter().zip(node.expressions().iter()) {
            if let Some(name) = var_name(var) {
                self.check_named(&name, expr);
            }
        }
    }

    fn visit_table_constructor(&mut self, node: &TableConstructor) {
        for field in node.fields() {
            match field {
                Field::NameKey { key, value, .. } => self.check_named(&token_name(key), value),
                Field::ExpressionKey { key, value, .. } => {
                    if let Expression::String(token) = &**key {
                        if let TokenType::StringLiteral { literal, .. } = token.token().token_type()
                        {
                            let name = literal.to_string();
                            self.check_named(&name, value);
                        }
                    }
                }
                _ => {}
            }
        }
    }

    fn visit_string_literal(&mut self, token: &Token) {
        if let TokenType::StringLiteral { literal, .. } = token.token_type() {
            let text = literal.to_string();
            self.scan_text(token, &text);
        }
    }

    fn visit_token(&mut self, token: &Token) {
        if let TokenType::InterpolatedString { literal, .. } = token.token_type() {
            let text = literal.to_string();
            self.scan_text(token, &text);
        }
    }
}

/// Finds secrets in a parsed file.
pub fn find_secrets(file: usize, ast: &full_moon::ast::Ast) -> Vec<SecretHit> {
    let mut visitor = SecretVisitor {
        file,
        hits: BTreeMap::new(),
    };
    visitor.visit_ast(ast);
    visitor.hits.into_values().collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn hits(code: &str) -> Vec<String> {
        let ast = full_moon::parse_fallible(code, full_moon::LuaVersion::luau()).into_ast();
        find_secrets(0, &ast)
            .into_iter()
            .map(|h| h.kind.to_string())
            .collect()
    }

    #[test]
    fn finds_webhooks_and_keys() {
        assert_eq!(
            hits(
                r#"local url = "https://discord.com/api/webhooks/123456789012345678/abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGH""#
            ),
            ["Discord webhook URL"]
        );
        assert_eq!(
            hits(r#"local k = "sk-proj-abcdefghijklmnopqrstuvwxyz123456""#),
            ["OpenAI API key"]
        );
        assert_eq!(
            hits(r#"local k = "sk-ant-api03-abcdefghijklmnopqrstuvwxyz123456""#),
            ["Anthropic API key"]
        );
        assert_eq!(
            hits(r#"local Config = { apiKey = "a8f3k29dk3l2m9x0q7w6e5r4" }"#),
            ["credential"]
        );
        assert_eq!(
            hits(r#"local h = { Authorization = "Bearer 9f8e7d6c5b4a39281706f5e4d3c2b1a0" }"#),
            ["credential"]
        );
    }

    #[test]
    fn ignores_placeholders_and_plain_text() {
        assert!(hits(r#"local WEBHOOK = "YOUR_WEBHOOK_URL_HERE""#).is_empty());
        assert!(hits(r#"local apiKey = "xxxxxxxxxxxxxxxxxxxxxxxx""#).is_empty());
        assert!(hits(r#"local author = "Builderman2024Studios""#).is_empty());
        assert!(hits(r#"local tokenLabel = "Tokens collected: 10""#).is_empty());
        assert!(hits(r#"local url = "https://games.roblox.com/v1/games""#).is_empty());
    }
}
