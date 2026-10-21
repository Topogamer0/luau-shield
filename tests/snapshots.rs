//! Snapshot tests of the three output formats (`cargo insta review` to update).

use luau_shield::config::Config;
use luau_shield::report;
use std::path::PathBuf;

fn check(path: &str) -> luau_shield::Report {
    luau_shield::check(&[PathBuf::from(path)], &Config::default()).unwrap()
}

#[test]
fn text_vulnerable_game() {
    let report = check("examples/vulnerable-game");
    insta::assert_snapshot!(report::text::render(&report, false, false));
}

#[test]
fn text_fixed_game() {
    let report = check("examples/fixed-game");
    assert!(report.findings.is_empty());
    insta::assert_snapshot!(report::text::render(&report, false, false));
}

#[test]
fn json_single_file() {
    let report = check("tests/fixtures/LS001/vulnerable");
    insta::assert_snapshot!(report::json::render(&report));
}

#[test]
fn sarif_vulnerable_game() {
    let report = check("examples/vulnerable-game");
    let sarif = report::sarif::render(&report);
    let parsed: serde_json::Value = serde_json::from_str(&sarif).unwrap();
    assert_eq!(parsed["version"], "2.1.0");
    insta::assert_snapshot!(sarif);
}
