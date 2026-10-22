# luau-shield

[![CI](https://github.com/Topogamer0/luau-shield/actions/workflows/ci.yml/badge.svg)](https://github.com/Topogamer0/luau-shield/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**luau-shield** is an open-source static security analyzer for Roblox games
written in Luau. It finds the bugs exploiters actually use: values sent by
the client through remotes that reach currency, DataStores, character
properties, `loadstring`, HTTP requests or other players' objects without
being validated.

It is a defensive tool: run it on your own code, locally or in CI, before an
exploiter finds the hole for you.

- **Real data-flow analysis, not regular expressions.** luau-shield parses
  every file into a syntax tree and follows untrusted values through
  variables, tables, string building, local functions and `require`d modules.
- **Understands validation.** `typeof` checks, bounds, NaN checks, allow-list
  lookups, ownership checks, early returns, `assert`, your own validation
  functions and the [`t`](https://github.com/osyrisrblx/t) library are
  recognised, so checked values are not reported.
- **Clear findings.** Every finding shows the code, the path of the data from
  the remote to the dangerous line, why it is exploitable and how to fix it.
- **Made for CI.** Text, JSON and SARIF output, exit codes, severity
  thresholds, a GitHub Action that uploads results to the Security tab.
- **One small binary** for Windows, macOS and Linux, no runtime dependencies.
  Installable with Rokit.

> Similar tools exist: LuauGuard looks for risky patterns with regular
> expressions and BeeScan looks for backdoors. luau-shield focuses on
> precision: few false positives, and an explanation for every finding.

## Contents

- [Installation](#installation)
- [Usage](#usage)
- [Example output](#example-output)
- [Rules](#rules)
- [How it works](#how-it-works)
- [Configuration](#configuration)
- [Suppressing a finding](#suppressing-a-finding)
- [Continuous integration](#continuous-integration)
- [AI explanations with Ollama (optional)](#ai-explanations-with-ollama-optional)
- [Accuracy](#accuracy)
- [Limitations](#limitations)
- [Development](#development)

## Installation

With [Rokit](https://github.com/rojo-rbx/rokit) (recommended for Roblox projects):

```sh
rokit add Topogamer0/luau-shield
```

This adds a line to your `rokit.toml`:

```toml
[tools]
luau-shield = "Topogamer0/luau-shield@0.1.0"
```

Aftman and Foreman work the same way (`luau-shield = "Topogamer0/luau-shield@0.1.0"`
in `aftman.toml`, or `luau-shield = { github = "Topogamer0/luau-shield", version = "0.1.0" }`
in `foreman.toml`).

Prebuilt binaries for Windows x64, macOS (Apple Silicon and Intel) and Linux
x64 are attached to every [GitHub release](https://github.com/Topogamer0/luau-shield/releases).
The Linux binary is fully static; the Windows binary does not need the Visual
C++ runtime.

From source (Rust 1.85 or newer):

```sh
cargo install --git https://github.com/Topogamer0/luau-shield --locked
```

## Usage

```sh
luau-shield check                       # analyse the current directory
luau-shield check src                   # analyse a directory
luau-shield check --format json -o report.json
luau-shield check --format sarif -o luau-shield.sarif
luau-shield check --min-severity high   # only high and critical findings
luau-shield check --disable luau-shield007       # turn a rule off
luau-shield rules                       # list the rules
luau-shield init                        # write a starter luau-shield.toml
```

| Option | Meaning |
| --- | --- |
| `-f, --format text\|json\|sarif` | Output format (default `text`). |
| `-o, --output FILE` | Write the report to a file instead of stdout. |
| `-c, --config FILE` | Configuration file (default: `luau-shield.toml` in the checked directory or a parent). `--no-config` ignores it. |
| `--project FILE` | Rojo project used to map files to the DataModel (default: `default.project.json`). |
| `-s, --min-severity LEVEL` | Only report findings at or above `low`, `medium`, `high` or `critical`. |
| `--fail-on LEVEL` | Exit with code 1 when a reported finding is at or above this severity (`never` to always succeed). Default: `low`. |
| `--disable RULES`, `--only RULES` | Comma-separated rule codes (`luau-shield003`) or names (`unverified-client-instance`). |
| `--explain`, `--ollama-model MODEL` | Ask a local model for a detailed explanation (see below). |
| `--color auto\|always\|never` | Colors in text output (`NO_COLOR` is honoured). |
| `-q, --quiet` | Only print the summary line. |

Exit codes: **0** no finding at or above `--fail-on`, **1** findings,
**2** usage, configuration or I/O error. Files that cannot be parsed are
reported as warnings and skipped.

luau-shield knows which code runs where: `*.server.luau` scripts run on the
server, `*.client.luau` LocalScripts on the client, and ModuleScripts take the
context of their location in the Rojo project (`ServerScriptService` and
`ServerStorage` are server-only, `ReplicatedStorage`, `ReplicatedFirst`,
`StarterPlayer`, `StarterGui` replicate to clients). Without a Rojo project,
directory names such as `server`, `client` and `shared` are used.

## Example output

```text
high[luau-shield001]: Client-controlled value written to currency, stats or saved data
  --> examples/vulnerable-game/src/server/Modules/DataManager.luau:74:3
   |
73 |     for key, value in changes do
74 |         profile[key] = value
   |         ^^^^^^^^^^^ `key` (client-controlled, from `changes`) chooses which entry of `profile` is written
   |
   = data flow:
       1. examples/vulnerable-game/src/server/PlayerData.server.luau:47:69
          `changes` (parameter #2) of the `Remotes.SaveSettings.OnServerEvent` handler is sent by
          the client (the type annotation `{ [string]: any }` is not checked at runtime)
       2. examples/vulnerable-game/src/server/PlayerData.server.luau:48:2
          passed to `DataManager.saveSettings` as `changes`
       3. examples/vulnerable-game/src/server/Modules/DataManager.luau:73:6
          assigned to `key`
       4. examples/vulnerable-game/src/server/Modules/DataManager.luau:74:3
          `key` (client-controlled, from `changes`) chooses which entry of `profile` is written
   = why: Exploiters can fire any remote with any arguments. If the server adds a client-supplied
           amount to a currency, saves a client-supplied table or lets the client pick the
           DataStore key, an exploiter can give themselves unlimited currency, corrupt other
           players' data or poison saves with NaN/huge values. Luau type annotations are erased at
           runtime: they do not validate anything.
   = fix: The key is not checked against an allow-list (or a strict pattern): the client chooses
           which entry is written, for example `Coins` or another player's save. Let the server
           decide amounts (look prices and rewards up in a server table by an allow-listed id).
           [...]
   = docs: https://github.com/Topogamer0/luau-shield/blob/main/docs/rules/luau-shield001.md

Found 27 problems (5 critical, 15 high, 1 medium, 6 low) in 15 files.
```

The full output for the example game is in
[`tests/snapshots/snapshots__text_vulnerable_game.snap`](tests/snapshots/snapshots__text_vulnerable_game.snap).
Try it yourself: `luau-shield check examples/vulnerable-game`, then
`luau-shield check examples/fixed-game` (no findings).

## Rules

| Code | Name | Severity | Finds |
| --- | --- | --- | --- |
| [luau-shield001](docs/rules/luau-shield001.md) | `untrusted-economy-write` | high | client values written to currency, leaderstats, player data, DataStores, MemoryStores |
| [luau-shield002](docs/rules/luau-shield002.md) | `untrusted-instance-property` | high | client values assigned to `Position`, `CFrame`, `Health`, `WalkSpeed`, `Parent`, `Text`... |
| [luau-shield003](docs/rules/luau-shield003.md) | `unverified-client-instance` | high | Instances sent by the client used without an ownership or location check |
| [luau-shield004](docs/rules/luau-shield004.md) | `untrusted-code-execution` | critical | client values reaching `loadstring`, `require`, `getfenv()[x]` |
| [luau-shield005](docs/rules/luau-shield005.md) | `untrusted-http-request` | high | client values in the URL, headers or body of `HttpService` requests |
| [luau-shield006](docs/rules/luau-shield006.md) | `server-invokes-client` | medium | `RemoteFunction:InvokeClient` on the server (can yield forever) |
| [luau-shield007](docs/rules/luau-shield007.md) | `remote-without-rate-limit` | low | remote handlers doing expensive work (`*Async`, `Instance.new`, `:Clone()`) with no rate limit |
| [luau-shield008](docs/rules/luau-shield008.md) | `client-exposed-secret` | critical | webhooks, API keys and tokens in code that replicates to clients |

Each rule page explains what is detected, the exploit, what counts as a
check, and the known limits. Short examples follow (the handlers come from a
`*.server.luau` script; `Remotes` is a folder of RemoteEvents).

### luau-shield001: untrusted-economy-write

```lua
-- Vulnerable: the client decides how many coins it gets (1e9, -1e9, NaN...)
Remotes.Collect.OnServerEvent:Connect(function(player, amount)
	player.leaderstats.Coins.Value += amount
end)
```

```lua
-- Fixed: the server decides the amount, the client only names an allowed pickup
local REWARDS = { Coin = 1, Gem = 10 }
Remotes.Collect.OnServerEvent:Connect(function(player, pickupKind)
	local reward = REWARDS[pickupKind]
	if not reward then return end
	player.leaderstats.Coins.Value += reward
end)
```

If a number really has to come from the client, check its type, both bounds
**and NaN**: `if typeof(n) ~= "number" or n ~= n or n < 1 or n > 100 then return end`.
`if n <= 0 or n > 100 then return end` alone lets NaN through, and luau-shield
says so.

### luau-shield002: untrusted-instance-property

```lua
-- Vulnerable: teleport anywhere
Remotes.Dash.OnServerEvent:Connect(function(player, position)
	player.Character.HumanoidRootPart.CFrame = CFrame.new(position)
end)
```

```lua
-- Fixed: the target must be a Vector3 close to the character
local MAX_DASH = 20
Remotes.Dash.OnServerEvent:Connect(function(player, position)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or typeof(position) ~= "Vector3" then return end
	if (position - root.Position).Magnitude > MAX_DASH then return end
	root.CFrame = CFrame.new(position)
end)
```

### luau-shield003: unverified-client-instance

```lua
-- Vulnerable: IsA proves it is a Tool, not that it is this player's Tool
Remotes.Unequip.OnServerEvent:Connect(function(player, tool)
	if typeof(tool) ~= "Instance" or not tool:IsA("Tool") then return end
	tool:Destroy()
end)
```

```lua
-- Fixed: the tool must be in the player's own backpack
Remotes.Unequip.OnServerEvent:Connect(function(player, tool)
	if typeof(tool) ~= "Instance" or not tool:IsDescendantOf(player.Backpack) then return end
	tool:Destroy()
end)
```

### luau-shield004: untrusted-code-execution

```lua
-- Vulnerable: remote code execution on the server
Remotes.Console.OnServerEvent:Connect(function(player, source)
	loadstring(source)()
end)
```

```lua
-- Fixed: the client picks a command from a server-side table
local Commands = {
	heal = function(player) player.Character.Humanoid.Health = 100 end,
}
Remotes.Console.OnServerEvent:Connect(function(player, name)
	local command = Commands[name]
	if command then command(player) end
end)
```

### luau-shield005: untrusted-http-request

```lua
-- Vulnerable: the client controls the path of a request sent by your server
Remotes.Lookup.OnServerEvent:Connect(function(player, path)
	HttpService:GetAsync("https://api.example.com/" .. path)
end)
```

```lua
-- Fixed: only a numeric id reaches the URL (and the remote is rate limited, see luau-shield007)
Remotes.Lookup.OnServerEvent:Connect(function(player, userId)
	local id = tonumber(userId)
	if not id then return end
	HttpService:GetAsync("https://api.example.com/users/" .. id)
end)
```

### luau-shield006: server-invokes-client

```lua
-- Vulnerable: an exploiter never answers and this thread waits forever
Remotes.Trade.OnServerEvent:Connect(function(player, partner)
	local accepted = Remotes.ConfirmTrade:InvokeClient(partner)
end)
```

```lua
-- Fixed: ask with a RemoteEvent, accept the answer on another RemoteEvent
-- (with a server-side timeout), never wait on the client
Remotes.Trade.OnServerEvent:Connect(function(player, partner)
	Remotes.TradeRequest:FireClient(partner, player)
end)
```

### luau-shield007: remote-without-rate-limit

```lua
-- Vulnerable: a DataStore write on every request
Remotes.Save.OnServerEvent:Connect(function(player)
	Store:SetAsync(tostring(player.UserId), player.leaderstats.Coins.Value)
end)
```

```lua
-- Fixed: at most one save every 30 seconds per player
local lastSave = {}
Remotes.Save.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if lastSave[player] and now - lastSave[player] < 30 then return end
	lastSave[player] = now
	Store:SetAsync(tostring(player.UserId), player.leaderstats.Coins.Value)
end)
```

### luau-shield008: client-exposed-secret

```lua
-- Vulnerable (in a LocalScript or a ModuleScript in ReplicatedStorage):
-- every player can read and abuse this webhook
local WEBHOOK = "https://discord.com/api/webhooks/1234567890/AbCdEf..."
```

```lua
-- Fixed (in ServerScriptService): use Roblox secrets, on the server only
local WEBHOOK = HttpService:GetSecret("discord_webhook")
```

## How it works

1. **Parsing** with [full-moon](https://github.com/Kampfkarren/full-moon), which
   supports all of modern Luau: type annotations, generics, type functions,
   compound assignment, `if` expressions, string interpolation, attributes.
2. **Project model**: the Rojo project maps files to the DataModel, so
   `require(game:GetService("ServerScriptService").Modules.Economy)`,
   `require(script.Parent.Economy)`, `require("./Economy")` and `.luaurc`
   aliases resolve to files. Each file gets a run context (server, client,
   replicated).
3. **Sources**: the parameters of `OnServerEvent`, `OnServerInvoke` and
   `UnreliableRemoteEvent` handlers (except `player`), values returned by
   `InvokeClient`, `Player.Chatted` messages, Knit `Service.Client` methods
   and your own [custom sources](docs/configuration.md).
4. **Abstract interpretation**: the server code is executed symbolically. Each
   value remembers which untrusted data it contains and which checks it
   passed. Branches are followed separately and merged, loops are iterated,
   calls into local functions and required modules are analysed with the
   actual arguments, validation functions are summarised.
5. **Sinks**: every rule decides whether the checks are enough for its sink;
   for example a number written to a currency needs a type check, both bounds
   and a NaN check, while an Instance needs an ownership or location check.

The exact semantics (what counts as a check, what propagates) are documented
in [docs/analysis.md](docs/analysis.md).

## Configuration

`luau-shield init` writes a commented [`luau-shield.toml`](luau-shield.example.toml):

```toml
min-severity = "low"
fail-on = "high"
ignore = ["src/dev/**"]

[rules]
luau-shield007 = "off"          # disable a rule
luau-shield006 = "high"         # change its severity

# Your own validation functions: values that pass them are trusted.
[[sanitizers]]
function = "Validate.amount"

# Your own dangerous functions.
[[sinks]]
function = "Economy.addCoins"
rule = "luau-shield001"
arguments = [2]

# Functions whose parameters come from the client (other networking libraries).
[[sources]]
function = "Net.handlers.*"
trusted-parameters = 1
```

Full reference: [docs/configuration.md](docs/configuration.md).

## Suppressing a finding

When luau-shield is wrong, or the risk is accepted, add a comment with the
rule and a reason, on the line of the finding or on the line above it:

```lua
coins.Value += amount -- luau-shield-ignore: luau-shield001 amount is validated by the gateway

-- luau-shield-ignore: luau-shield003 doors are re-checked by DoorService
door:Destroy()
```

`-- luau-shield-ignore-file: luau-shield007 reason` anywhere in a file suppresses a rule
for the whole file. Suppressed findings are counted in the summary.

## Continuous integration

GitHub Actions, with results in the **Security → Code scanning** tab and on
pull requests:

```yaml
name: luau-shield
on: [push, pull_request]
permissions:
  contents: read
  security-events: write
jobs:
  luau-shield:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: Topogamer0/luau-shield@v0.1.0
        with:
          path: src
          fail-on: high
```

The action downloads the release binary, runs the analysis, uploads the SARIF
report and then fails the job if there are findings at or above `fail-on`.
Other CI systems only need the binary and the exit code. See
[docs/ci.md](docs/ci.md).

## AI explanations with Ollama (optional)

`--explain` sends each finding (with the surrounding code) to a local model
served by [Ollama](https://ollama.com) and prints a longer explanation and a
suggested fix under the finding. Nothing leaves your machine, and luau-shield
works exactly the same without it.

```sh
ollama pull qwen2.5-coder:7b
luau-shield check --explain                       # uses OLLAMA_HOST or http://localhost:11434
luau-shield check --explain --ollama-model llama3.1 --explain-limit 5
```

The model is set with `--ollama-model` or `[explain] model` in the
configuration. Model output can be wrong: the static finding is the source of
truth. Only plain HTTP Ollama endpoints are supported.

## Accuracy

The test corpus in [`tests/fixtures`](tests/fixtures) contains, for every rule,
vulnerable cases and closely related safe cases that are validated correctly.
`cargo test --test corpus` runs luau-shield on all of them and compares the
findings with the expected ones line by line.

<!-- corpus-table -->

`tests/fixtures/limitations` holds cases that luau-shield is known to get
wrong; they are counted separately and listed below.

## Limitations

Static analysis approximates what the program does: it can be wrong in both
directions.

- **Dynamic code cannot be followed**: `getfenv`/`setfenv`, `loadstring`,
  metatable tricks, functions chosen at runtime by name, and modules required
  through computed paths (`require(Shops[mode])`).
- **Data that leaves Luau variables is lost**: values relayed through
  BindableEvents, signals, attributes, `ValueBase` objects or the DataStore and
  read back later are not followed.
- **Tables are tracked by value**: a write through one alias of a table is not
  seen through another alias. A check on a copy of a variable does not protect
  the original.
- **Heuristics on names**: currencies and stats are recognised by names
  (`leaderstats`, `Coins`, `Cash`, `Gems`, ...), DataStores by
  `GetDataStore`/`*Store`, rate limits by time functions, locks and names such
  as `cooldown` or `RateLimiter`. Functions that cannot be resolved but are
  named like validators (`isValidItem`) are trusted when used as guards (this
  can be turned off).
- **Checks are not proven correct**: a bound that is too large still counts as
  a bound.
- **Depth**: loops are analysed a bounded number of times and calls are
  followed up to `max-call-depth` (default 6).

Every known mistake has a test in
[`tests/fixtures/limitations`](tests/fixtures/limitations). When luau-shield is
wrong on your code, suppress the finding with a reason, add a
[custom sanitizer](docs/configuration.md), or open an issue with a minimal
example.

## Development

```sh
cargo test                          # unit, engine, corpus and snapshot tests
cargo test --test corpus -- --nocapture   # corpus table with false positives/negatives
cargo insta review                  # review snapshot changes
cargo clippy --all-targets -- -D warnings
cargo fmt --all
```

To add a test case, drop a file (or a small Rojo project) in
`tests/fixtures/<RULE>/vulnerable` or `safe` and mark expected findings with
`-- expect: luau-shield001` at the end of the line (see
[tests/fixtures/README.md](tests/fixtures/README.md)).

## License

[MIT](LICENSE)
