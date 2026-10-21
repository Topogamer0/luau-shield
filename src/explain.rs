//! Optional `--explain`: asks a local model served by Ollama for a longer
//! explanation and a suggested fix. luau-shield works the same without it.

use crate::Report;
use crate::finding::Finding;
use std::time::Duration;

/// The Ollama base URL from `OLLAMA_HOST` (default `http://localhost:11434`).
pub fn ollama_base_url() -> String {
    let raw = std::env::var("OLLAMA_HOST").unwrap_or_default();
    normalize_host(raw.trim())
}

fn normalize_host(raw: &str) -> String {
    if raw.is_empty() {
        return "http://localhost:11434".to_string();
    }
    let with_scheme = if raw.starts_with("http://") || raw.starts_with("https://") {
        raw.to_string()
    } else {
        format!("http://{raw}")
    };
    let (scheme, rest) = with_scheme
        .split_once("://")
        .unwrap_or(("http", &with_scheme));
    let rest = rest.trim_end_matches('/');
    // `0.0.0.0` is a bind address, not something we can connect to.
    let rest = rest.replacen("0.0.0.0", "127.0.0.1", 1);
    let has_port = rest
        .rsplit_once(':')
        .is_some_and(|(_, port)| port.chars().all(|c| c.is_ascii_digit()) && !port.is_empty());
    if has_port || scheme == "https" {
        format!("{scheme}://{rest}")
    } else {
        format!("{scheme}://{rest}:11434")
    }
}

fn excerpt(source: &str, center: usize, radius: usize) -> String {
    let lines: Vec<&str> = source.lines().collect();
    let start = center.saturating_sub(radius + 1);
    let end = (center + radius).min(lines.len());
    lines[start..end]
        .iter()
        .enumerate()
        .map(|(i, l)| format!("{:>4} | {l}", start + i + 1))
        .collect::<Vec<_>>()
        .join("\n")
}

fn prompt(finding: &Finding, report: &Report) -> String {
    let mut text = String::new();
    text.push_str(
        "You are a senior Roblox security engineer reviewing server code written in Luau. \
         A static analyzer (luau-shield) reported the finding below. Explain concisely, for the \
         developer who owns this code: (1) how an exploiter would abuse it, step by step; \
         (2) a corrected version of the relevant code in Luau, keeping the developer's style; \
         (3) if you believe the finding is a false positive, say so and why. \
         Never trust values sent by the client. Keep the answer under 250 words.\n\n",
    );
    text.push_str(&format!(
        "Rule: {} ({})\nSeverity: {}\nFile: {}:{}\nMessage: {}\nWhy: {}\nSuggested fix: {}\n",
        finding.rule,
        finding.title,
        finding.severity,
        finding.file,
        finding.span.line,
        finding.message,
        finding.why,
        finding.fix
    ));
    if finding.flow.len() > 1 {
        text.push_str("Data flow:\n");
        for (i, step) in finding.flow.iter().enumerate() {
            text.push_str(&format!(
                "  {}. {}:{}: {}\n",
                i + 1,
                step.file,
                step.line,
                step.note
            ));
        }
    }
    if let Some(source) = report.sources.get(&finding.file) {
        text.push_str("\nCode around the finding:\n```lua\n");
        text.push_str(&excerpt(source, finding.span.line, 12));
        text.push_str("\n```\n");
    }
    if let Some(first) = finding.flow.first() {
        if first.file != finding.file || first.line + 12 < finding.span.line {
            if let Some(source) = report.sources.get(&first.file) {
                text.push_str("\nCode where the data comes from:\n```lua\n");
                text.push_str(&excerpt(source, first.line, 6));
                text.push_str("\n```\n");
            }
        }
    }
    text
}

/// Adds explanations to at most `limit` findings. Returns how many were
/// explained, or an error message if Ollama cannot be reached at all.
pub fn explain(
    report: &mut Report,
    model: &str,
    timeout_seconds: u64,
    limit: usize,
) -> Result<usize, String> {
    let base = ollama_base_url();
    let url = format!("{base}/api/generate");
    let config = ureq::Agent::config_builder()
        .timeout_global(Some(Duration::from_secs(timeout_seconds)))
        .http_status_as_error(false)
        .build();
    let agent = ureq::Agent::new_with_config(config);
    let mut explained = 0;
    let prompts: Vec<String> = report
        .findings
        .iter()
        .take(limit)
        .map(|f| prompt(f, report))
        .collect();
    for (index, prompt) in prompts.into_iter().enumerate() {
        let body = serde_json::json!({
            "model": model,
            "prompt": prompt,
            "stream": false,
            "options": { "temperature": 0.2 },
        });
        let response = agent
            .post(&url)
            .header("Content-Type", "application/json")
            .send(body.to_string());
        let mut response = match response {
            Ok(r) => r,
            Err(e) => {
                if explained == 0 {
                    return Err(format!(
                        "cannot reach Ollama at {base} ({e}); is `ollama serve` running?"
                    ));
                }
                break;
            }
        };
        let status = response.status();
        let text = response
            .body_mut()
            .read_to_string()
            .map_err(|e| e.to_string())?;
        if !status.is_success() {
            let detail: String = text.chars().take(200).collect();
            return Err(format!(
                "Ollama answered {status}: {detail} (is the model `{model}` pulled? try `ollama pull {model}`)"
            ));
        }
        let parsed: serde_json::Value = serde_json::from_str(&text)
            .map_err(|e| format!("unexpected answer from Ollama: {e}"))?;
        if let Some(answer) = parsed.get("response").and_then(|r| r.as_str()) {
            report.findings[index].ai_explanation = Some(answer.trim().to_string());
            explained += 1;
        }
    }
    Ok(explained)
}

#[cfg(test)]
mod tests {
    use super::normalize_host;

    #[test]
    fn hosts() {
        assert_eq!(normalize_host(""), "http://localhost:11434");
        assert_eq!(normalize_host("0.0.0.0"), "http://127.0.0.1:11434");
        assert_eq!(normalize_host("localhost:8080"), "http://localhost:8080");
        assert_eq!(
            normalize_host("http://gpu-box:11434/"),
            "http://gpu-box:11434"
        );
        assert_eq!(
            normalize_host("https://ollama.example.com"),
            "https://ollama.example.com"
        );
    }
}
