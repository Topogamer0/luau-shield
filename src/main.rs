use anstream::{AutoStream, ColorChoice};
use clap::{Args, Parser, Subcommand, ValueEnum};
use luau_shield::config::{CONFIG_FILE_NAME, Config, STARTER_CONFIG, parse_fail_on};
use luau_shield::report::{self, Format};
use luau_shield::rules::{RULES, RuleId, Severity};
use std::io::{IsTerminal, Write};
use std::path::{Path, PathBuf};
use std::process::ExitCode;

/// Static security analysis for Roblox games written in Luau.
///
/// luau-shield follows data sent by clients through remotes and reports where
/// it reaches currency, DataStores, Instance properties, loadstring/require or
/// HTTP requests without validation, plus a few other exploitable patterns.
#[derive(Parser)]
#[command(name = "luau-shield", version, about, long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Analyse files and directories (default: the current directory)
    Check(Box<CheckArgs>),
    /// List the rules
    Rules {
        /// Output format
        #[arg(short, long, value_enum, default_value_t = OutputFormat::Text)]
        format: OutputFormat,
    },
    /// Write a starter luau-shield.toml
    Init {
        /// Directory to write the configuration to
        #[arg(default_value = ".")]
        dir: PathBuf,
        /// Overwrite an existing file
        #[arg(long)]
        force: bool,
    },
}

#[derive(Clone, Copy, ValueEnum)]
enum OutputFormat {
    Text,
    Json,
    Sarif,
}

#[derive(Clone, Copy, ValueEnum)]
enum ColorMode {
    Auto,
    Always,
    Never,
}

#[derive(Args)]
struct CheckArgs {
    /// Files or directories to analyse
    #[arg(default_value = ".")]
    paths: Vec<PathBuf>,
    /// Output format
    #[arg(short, long, value_enum, default_value_t = OutputFormat::Text)]
    format: OutputFormat,
    /// Write the report to a file instead of stdout
    #[arg(short, long)]
    output: Option<PathBuf>,
    /// Configuration file (default: luau-shield.toml in the checked directory or a parent)
    #[arg(short, long)]
    config: Option<PathBuf>,
    /// Ignore luau-shield.toml files
    #[arg(long, conflicts_with = "config")]
    no_config: bool,
    /// Rojo project file used to map files to instances (default: default.project.json)
    #[arg(long)]
    project: Option<PathBuf>,
    /// Only report findings at or above this severity
    #[arg(short = 's', long, value_name = "SEVERITY")]
    min_severity: Option<String>,
    /// Exit with code 1 when a reported finding is at or above this severity ("never" to always exit 0)
    #[arg(long, value_name = "SEVERITY|never")]
    fail_on: Option<String>,
    /// Disable rules (comma-separated codes or names)
    #[arg(long, value_delimiter = ',', value_name = "RULES")]
    disable: Vec<String>,
    /// Only run these rules (comma-separated codes or names)
    #[arg(long, value_delimiter = ',', value_name = "RULES")]
    only: Vec<String>,
    /// Ask a local model (Ollama, OLLAMA_HOST) for a detailed explanation of each finding
    #[arg(long)]
    explain: bool,
    /// Ollama model used by --explain
    #[arg(long, value_name = "MODEL")]
    ollama_model: Option<String>,
    /// Maximum number of findings sent to the model
    #[arg(long, default_value_t = 20, value_name = "N")]
    explain_limit: usize,
    /// When to use colors in text output
    #[arg(long, value_enum, default_value_t = ColorMode::Auto)]
    color: ColorMode,
    /// Only print the summary line (text format)
    #[arg(short, long)]
    quiet: bool,
    /// Do not exit with code 2 when some files cannot be read or parsed
    #[arg(long)]
    allow_parse_errors: bool,
}

fn main() -> ExitCode {
    let cli = Cli::parse();
    match cli.command {
        Command::Check(args) => match run_check(*args) {
            Ok(code) => code,
            Err(message) => {
                eprintln!("error: {message}");
                ExitCode::from(2)
            }
        },
        Command::Rules { format } => {
            print_rules(format);
            ExitCode::SUCCESS
        }
        Command::Init { dir, force } => match init(&dir, force) {
            Ok(path) => {
                println!("Wrote {}", path.display());
                ExitCode::SUCCESS
            }
            Err(message) => {
                eprintln!("error: {message}");
                ExitCode::from(2)
            }
        },
    }
}

fn parse_rules(list: &[String]) -> Result<Vec<RuleId>, String> {
    list.iter()
        .filter(|s| !s.trim().is_empty())
        .map(|s| s.parse::<RuleId>())
        .collect()
}

fn load_config(args: &CheckArgs) -> Result<Config, String> {
    let mut config = if args.no_config {
        Config::default()
    } else if let Some(path) = &args.config {
        Config::load(path)?
    } else {
        let start = args
            .paths
            .first()
            .cloned()
            .unwrap_or_else(|| PathBuf::from("."));
        match Config::discover(&start) {
            Some(path) => Config::load(&path)?,
            None => Config::default(),
        }
    };
    if let Some(s) = &args.min_severity {
        config.min_severity = s.parse::<Severity>()?;
    }
    if let Some(s) = &args.fail_on {
        config.fail_on = parse_fail_on(s)?;
    } else if args.min_severity.is_some() && config.fail_on.is_some_and(|f| f < config.min_severity)
    {
        // Do not fail on findings that are not even reported.
        config.fail_on = Some(config.min_severity);
    }
    if let Some(project) = &args.project {
        config.project = Some(project.clone());
    }
    for rule in parse_rules(&args.disable)? {
        if let Some(setting) = config.rules.get_mut(&rule) {
            setting.enabled = false;
        }
    }
    let only = parse_rules(&args.only)?;
    if !only.is_empty() {
        // Flags win over the configuration file: `--only` also turns back on
        // a rule that luau-shield.toml disables.
        for (rule, setting) in config.rules.iter_mut() {
            setting.enabled = only.contains(rule);
        }
    }
    if let Some(model) = &args.ollama_model {
        config.explain_model = model.clone();
    }
    if args.allow_parse_errors {
        config.allow_parse_errors = true;
    }
    Ok(config)
}

fn run_check(args: CheckArgs) -> Result<ExitCode, String> {
    let config = load_config(&args)?;
    let mut report = luau_shield::check(&args.paths, &config)?;

    let to_stdout = args.output.is_none();
    let color = match args.color {
        ColorMode::Always => true,
        ColorMode::Never => false,
        ColorMode::Auto => {
            to_stdout && std::io::stdout().is_terminal() && std::env::var_os("NO_COLOR").is_none()
        }
    };
    let mut stderr = AutoStream::new(
        std::io::stderr(),
        if color {
            ColorChoice::Auto
        } else {
            ColorChoice::Never
        },
    );
    for warning in &report.warnings {
        let _ = writeln!(stderr, "warning: {warning}");
    }
    for failure in &report.parse_failures {
        let _ = writeln!(
            stderr,
            "warning: could not parse {}:{}:{}: {} (file skipped)",
            failure.file, failure.line, failure.column, failure.message
        );
    }
    if args.explain && !report.findings.is_empty() {
        let _ = writeln!(
            stderr,
            "Asking {} at {} to explain {} finding(s)...",
            config.explain_model,
            luau_shield::explain::ollama_base_url(),
            report.findings.len().min(args.explain_limit)
        );
        if let Err(message) = luau_shield::explain::explain(
            &mut report,
            &config.explain_model,
            config.explain_timeout_seconds,
            args.explain_limit,
        ) {
            let _ = writeln!(stderr, "warning: --explain: {message}");
        }
    }

    let format = match args.format {
        OutputFormat::Text => Format::Text,
        OutputFormat::Json => Format::Json,
        OutputFormat::Sarif => Format::Sarif,
    };
    let rendered = match format {
        Format::Text => report::text::render(&report, color, args.quiet),
        Format::Json => report::json::render(&report),
        Format::Sarif => report::sarif::render(&report),
    };
    match &args.output {
        Some(path) => {
            std::fs::write(path, rendered)
                .map_err(|e| format!("cannot write {}: {e}", path.display()))?;
            if format != Format::Text || args.quiet {
                let summary = report::text::render(&report, false, true);
                let _ = write!(stderr, "{summary}");
            }
        }
        None => {
            let mut stdout = std::io::stdout().lock();
            if stdout.write_all(rendered.as_bytes()).is_err() {
                return Ok(ExitCode::from(2));
            }
        }
    }
    if report.incomplete(&config) {
        let _ = writeln!(
            stderr,
            "error: {} file(s) could not be analysed (see the warnings above); fix them, ignore them in luau-shield.toml or pass --allow-parse-errors",
            report.parse_failures.len()
        );
        return Ok(ExitCode::from(2));
    }
    Ok(if report.fails(&config) {
        ExitCode::from(1)
    } else {
        ExitCode::SUCCESS
    })
}

fn print_rules(format: OutputFormat) {
    match format {
        OutputFormat::Text => {
            for meta in RULES.iter() {
                println!(
                    "{}  {:<8}  {}  ({})",
                    meta.code,
                    meta.severity.as_str(),
                    meta.title,
                    meta.slug
                );
                println!("        {}", meta.summary);
                println!();
            }
        }
        OutputFormat::Json | OutputFormat::Sarif => {
            let rules: Vec<serde_json::Value> = RULES
                .iter()
                .map(|meta| {
                    let mut value = serde_json::to_value(meta).expect("rule metadata serializes");
                    value["help_uri"] = serde_json::json!(meta.help_uri());
                    value
                })
                .collect();
            println!(
                "{}",
                serde_json::to_string_pretty(&rules).expect("rules serialize")
            );
        }
    }
}

fn init(dir: &Path, force: bool) -> Result<PathBuf, String> {
    let path = dir.join(CONFIG_FILE_NAME);
    if path.exists() && !force {
        return Err(format!(
            "{} already exists (use --force to overwrite)",
            path.display()
        ));
    }
    std::fs::create_dir_all(dir).map_err(|e| format!("cannot create {}: {e}", dir.display()))?;
    std::fs::write(&path, STARTER_CONFIG)
        .map_err(|e| format!("cannot write {}: {e}", path.display()))?;
    Ok(path)
}
