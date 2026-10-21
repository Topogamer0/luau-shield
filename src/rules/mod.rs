//! Rule metadata: identifiers, default severities and the human explanations
//! attached to every finding.

pub mod invoke_client;
pub mod secrets;
pub mod sinks;

use serde::Serialize;
use std::fmt;
use std::str::FromStr;

/// How bad a finding is. Ordered from least to most severe.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum Severity {
    Low,
    Medium,
    High,
    Critical,
}

impl Severity {
    pub fn as_str(self) -> &'static str {
        match self {
            Severity::Low => "low",
            Severity::Medium => "medium",
            Severity::High => "high",
            Severity::Critical => "critical",
        }
    }

    /// SARIF only knows `note`, `warning` and `error`.
    pub fn sarif_level(self) -> &'static str {
        match self {
            Severity::Low => "note",
            Severity::Medium => "warning",
            Severity::High | Severity::Critical => "error",
        }
    }

    /// Numeric score used by GitHub code scanning (`security-severity`).
    pub fn security_score(self) -> &'static str {
        match self {
            Severity::Low => "3.0",
            Severity::Medium => "5.5",
            Severity::High => "8.0",
            Severity::Critical => "9.5",
        }
    }
}

impl fmt::Display for Severity {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.as_str())
    }
}

impl FromStr for Severity {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_ascii_lowercase().as_str() {
            "low" => Ok(Severity::Low),
            "medium" => Ok(Severity::Medium),
            "high" => Ok(Severity::High),
            "critical" => Ok(Severity::Critical),
            other => Err(format!(
                "unknown severity `{other}` (expected low, medium, high or critical)"
            )),
        }
    }
}

/// Every rule luau-shield knows about.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum RuleId {
    Ls001,
    Ls002,
    Ls003,
    Ls004,
    Ls005,
    Ls006,
    Ls007,
    Ls008,
}

impl RuleId {
    pub const ALL: [RuleId; 8] = [
        RuleId::Ls001,
        RuleId::Ls002,
        RuleId::Ls003,
        RuleId::Ls004,
        RuleId::Ls005,
        RuleId::Ls006,
        RuleId::Ls007,
        RuleId::Ls008,
    ];

    pub fn code(self) -> &'static str {
        self.meta().code
    }

    pub fn meta(self) -> &'static RuleMeta {
        &RULES[self as usize]
    }
}

impl fmt::Display for RuleId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.code())
    }
}

impl Serialize for RuleId {
    fn serialize<S: serde::Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        serializer.serialize_str(self.code())
    }
}

impl FromStr for RuleId {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let wanted = s.trim();
        RuleId::ALL
            .into_iter()
            .find(|rule| rule.code().eq_ignore_ascii_case(wanted) || rule.meta().slug == wanted)
            .ok_or_else(|| {
                format!("unknown rule `{wanted}` (run `luau-shield rules` for the list)")
            })
    }
}

/// Static description of a rule.
#[derive(Debug, Serialize)]
pub struct RuleMeta {
    pub code: &'static str,
    pub slug: &'static str,
    pub title: &'static str,
    pub severity: Severity,
    /// One sentence describing what the rule finds.
    pub summary: &'static str,
    /// Why the pattern is exploitable.
    pub why: &'static str,
    /// How to fix it.
    pub fix: &'static str,
}

impl RuleMeta {
    pub fn help_uri(&self) -> String {
        format!(
            "https://github.com/Topogamer0/luau-shield/blob/main/docs/rules/{}.md",
            self.code
        )
    }
}

pub static RULES: [RuleMeta; 8] = [
    RuleMeta {
        code: "LS001",
        slug: "untrusted-economy-write",
        title: "Client-controlled value written to currency, stats or saved data",
        severity: Severity::High,
        summary: "A value sent by the client reaches leaderstats, currency/stat fields, player data tables, DataStores or MemoryStores without being validated.",
        why: "Exploiters can fire any remote with any arguments. If the server adds a client-supplied amount to a currency, saves a client-supplied table or lets the client pick the DataStore key, an exploiter can give themselves unlimited currency, corrupt other players' data or poison saves with NaN/huge values.",
        fix: "Let the server decide amounts (look prices and rewards up in a server table by an allow-listed id). If a number must come from the client, check `typeof(x) == \"number\"`, reject NaN (`x ~= x`) and check both bounds before using it. Never use client data as a DataStore key.",
    },
    RuleMeta {
        code: "LS002",
        slug: "untrusted-instance-property",
        title: "Client-controlled value assigned to a sensitive Instance property",
        severity: Severity::High,
        summary: "A value sent by the client is assigned to a property such as Position, CFrame, Health, WalkSpeed, Parent or Text, or passed to PivotTo/TakeDamage/ApplyImpulse/SetAttribute.",
        why: "The server replicates these properties to everyone. Trusting the client lets exploiters teleport, fly, heal themselves, kill other players, move or delete parts, or display unfiltered text to other players.",
        fix: "Compute the value on the server (from server-side stats, the character's real position, etc.). If it must come from the client, clamp it to a sensible range, check distances against the character, allow-list instances, and filter text with TextService.",
    },
    RuleMeta {
        code: "LS003",
        slug: "unverified-client-instance",
        title: "Instance sent by the client used without checking ownership or location",
        severity: Severity::High,
        summary: "An Instance received from a remote is modified, destroyed, moved or used as a source of data without verifying that it belongs to the player or is where it should be.",
        why: "A remote can be fired with any Instance the client can see: another player's tool, a door on the other side of the map, a part of someone else's plot. Type checks such as `IsA` only prove what kind of object it is, not that the player is allowed to touch it.",
        fix: "Verify ownership or location before using the Instance: `inst:IsDescendantOf(player.Character)`, compare an `Owner` attribute with `player.UserId`, check the distance to the character, or look it up in a server-side list of allowed instances.",
    },
    RuleMeta {
        code: "LS004",
        slug: "untrusted-code-execution",
        title: "Client-controlled value reaches loadstring/require",
        severity: Severity::Critical,
        summary: "A value sent by the client reaches `loadstring`, `load`, `require` or a dynamic global lookup (`getfenv()[x]`, `_G[x]`).",
        why: "This gives the client remote code execution on the server: an exploiter can run arbitrary code with server privileges, require malicious assets by id, delete the game, steal data or ban players.",
        fix: "Never run code or require modules chosen by the client. Dispatch commands through a server-side table of allowed functions (`Commands[name]`) and validate the name against it.",
    },
    RuleMeta {
        code: "LS005",
        slug: "untrusted-http-request",
        title: "Client-controlled URL, headers or body in an HttpService request",
        severity: Severity::High,
        summary: "A value sent by the client is used to build the URL, headers or body of `HttpService:GetAsync/PostAsync/RequestAsync`.",
        why: "The client can make your server send requests to arbitrary endpoints or paths, abuse your webhooks and proxies (spam, @everyone pings, Terms of Service violations that get the webhook or game banned) and exhaust the HttpService request budget.",
        fix: "Keep URLs on the server and choose them through an allow-listed key. Encode client values with `HttpService:UrlEncode`, convert ids with `tonumber`, limit the length of text and rate-limit the remote.",
    },
    RuleMeta {
        code: "LS006",
        slug: "server-invokes-client",
        title: "Server waits for a client with RemoteFunction:InvokeClient",
        severity: Severity::Medium,
        summary: "The server calls `RemoteFunction:InvokeClient` (or assigns `OnClientInvoke`), so it depends on an answer from an untrusted client.",
        why: "A malicious client can simply never return: the server thread yields forever (pcall does not help), leaking memory and blocking whatever logic waits for the answer. A client that errors or leaves also breaks the call, and every value it returns is client-controlled.",
        fix: "Use a RemoteEvent for the request and another for the reply (with a server-side timeout), or at least run the invoke in a detached thread (`task.spawn`) with a timeout and validate the returned values.",
    },
    RuleMeta {
        code: "LS007",
        slug: "remote-without-rate-limit",
        title: "Remote handler does expensive work without a rate limit",
        severity: Severity::Low,
        summary: "A remote handler calls `*Async` APIs, `Instance.new` or `:Clone()` and has no visible rate limit or debounce.",
        why: "Exploiters can fire a remote thousands of times per second. Without a limit, each call spends DataStore/HTTP budgets, creates instances or yields, which is enough to lag or crash the server and to exhaust request quotas for everyone.",
        fix: "Add a per-player cooldown (store `os.clock()` per player and return early when called too often), a busy flag while the previous request is running, or a shared rate limiter module.",
    },
    RuleMeta {
        code: "LS008",
        slug: "client-exposed-secret",
        title: "Secret hard-coded in code that replicates to clients",
        severity: Severity::Critical,
        summary: "A webhook URL, API key, token or cookie is written in a LocalScript or in a ModuleScript that clients can read.",
        why: "Exploiters can decompile every LocalScript and replicated ModuleScript. A leaked webhook can be spammed or deleted, and a leaked API key gives full access to the account or service behind it.",
        fix: "Move the secret to the server (ServerScriptService/ServerStorage), store it with Roblox secrets (`HttpService:GetSecret`) and revoke the leaked credential.",
    },
];

/// Splits an identifier into lowercase words (`TotalCoins` -> `total`, `coins`).
pub fn identifier_words(name: &str) -> Vec<String> {
    let mut words = Vec::new();
    let mut current = String::new();
    let chars: Vec<char> = name.chars().collect();
    for (i, &c) in chars.iter().enumerate() {
        if !c.is_alphanumeric() {
            if !current.is_empty() {
                words.push(std::mem::take(&mut current));
            }
            continue;
        }
        if c.is_uppercase() && !current.is_empty() {
            let prev = chars[i - 1];
            let next_lower = chars.get(i + 1).is_some_and(|n| n.is_lowercase());
            if prev.is_lowercase() || prev.is_ascii_digit() || (prev.is_uppercase() && next_lower) {
                words.push(std::mem::take(&mut current));
            }
        }
        current.extend(c.to_lowercase());
    }
    if !current.is_empty() {
        words.push(current);
    }
    words
}

const STAT_WORDS: &[&str] = &[
    "coins",
    "coin",
    "cash",
    "money",
    "gold",
    "gems",
    "gem",
    "diamonds",
    "diamond",
    "points",
    "xp",
    "exp",
    "experience",
    "level",
    "levels",
    "kills",
    "wins",
    "score",
    "credits",
    "tokens",
    "bucks",
    "balance",
    "currency",
    "robux",
    "rebirths",
    "crystals",
    "stats",
    "leaderstats",
];

const DATA_WORDS: &[&str] = &[
    "data",
    "profile",
    "profiles",
    "save",
    "saves",
    "savedata",
    "playerdata",
    "session",
    "inventory",
    "stats",
    "leaderstats",
];

/// Is this identifier the name of a currency or player statistic?
pub fn is_stat_name(name: &str) -> bool {
    identifier_words(name)
        .iter()
        .any(|word| STAT_WORDS.contains(&word.as_str()))
}

/// Is this identifier the name of a container of persistent player data?
pub fn is_data_container_name(name: &str) -> bool {
    identifier_words(name)
        .iter()
        .any(|word| DATA_WORDS.contains(&word.as_str()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn splits_identifiers() {
        assert_eq!(identifier_words("TotalCoins"), ["total", "coins"]);
        assert_eq!(identifier_words("PlayerXP"), ["player", "xp"]);
        assert_eq!(identifier_words("HTTPService"), ["http", "service"]);
        assert_eq!(identifier_words("gems_balance"), ["gems", "balance"]);
        assert_eq!(identifier_words("leaderstats"), ["leaderstats"]);
    }

    #[test]
    fn recognises_stats() {
        assert!(is_stat_name("Coins"));
        assert!(is_stat_name("TotalCoins"));
        assert!(is_stat_name("XP"));
        assert!(!is_stat_name("spawnPoint"));
        assert!(!is_stat_name("Position"));
        assert!(is_data_container_name("PlayerData"));
        assert!(is_data_container_name("profile"));
    }

    #[test]
    fn rule_ids_round_trip() {
        for rule in RuleId::ALL {
            assert_eq!(rule.code().parse::<RuleId>().unwrap(), rule);
            assert_eq!(rule.meta().slug.parse::<RuleId>().unwrap(), rule);
        }
        assert_eq!("ls003".parse::<RuleId>().unwrap(), RuleId::Ls003);
    }
}
