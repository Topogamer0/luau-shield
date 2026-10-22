# Configuration

luau-shield works without any configuration. A `luau-shield.toml` file lets
you change which findings are reported and when the command fails, skip
files, and teach the analyzer about your own validation functions, sensitive
functions and remote frameworks.

Create a commented starter file in the current directory with:

```sh
luau-shield init
```

It writes the content of
[`luau-shield.example.toml`](../luau-shield.example.toml).

## Where the configuration comes from

**Discovery.** luau-shield looks for a file named `luau-shield.toml` in the
directory being checked (for a file: its directory), then in each parent
directory, and uses the first one it finds. Put it at the root of your
repository, next to `default.project.json`. To use a file with another name
or location, pass it explicitly:

```sh
luau-shield check src --config ci/luau-shield.toml
```

When you check several paths at once, pass `--config` so the choice does not
depend on the order of the paths.

**Relative paths** in the file (`project`, `ignore`) are resolved from the
directory that contains the configuration file, not from the current
directory.

**Precedence.** Built-in defaults < `luau-shield.toml` < command-line flags.
A flag always wins over the file:

| Setting | In `luau-shield.toml` | Command-line flag |
| --- | --- | --- |
| Lowest reported severity | `min-severity` | `-s`, `--min-severity` |
| Severity that fails the run | `fail-on` | `--fail-on` |
| Rojo project | `project` | `--project` |
| Rules that run | `[rules]` | `--disable luau-shield006,luau-shield007`, `--only luau-shield001` |
| Ollama model for `--explain` | `[explain] model` | `--ollama-model` |

`--disable` turns the listed rules off on top of `[rules]`. `--only` runs the
listed rules and nothing else; because flags win, a rule named in `--only`
runs even if the file turns it off.

An invalid configuration file (TOML syntax error, wrong value) makes
luau-shield exit with code `2`.

## Reference

```toml
min-severity = "low"                          # info | low | medium | high | critical
fail-on = "low"                               # info | low | medium | high | critical | never
project = "default.project.json"              # Rojo project used to map files to instances
ignore = ["Packages/**", "**/*.spec.luau"]    # globs relative to the config file directory
trust-unresolved-validators = true
max-call-depth = 6
allow-parse-errors = false

[rules]
luau-shield007 = "off"
luau-shield006 = "high"

[[sanitizers]]
function = "Validate.amount"
checks = "all"

[[sinks]]
function = "Economy.addCoins"
rule = "luau-shield001"
arguments = [2]

[[sources]]
function = "*.Client.*"
trusted-parameters = 1

[guards]
functions = ["Admins.isAdmin"]
defaults = true

[explain]
model = "qwen2.5-coder:7b"
timeout-seconds = 60
```

### Top-level keys

| Key | Type | Default | Meaning |
| --- | --- | --- | --- |
| `min-severity` | string | `"low"` | Lowest severity that is reported: `info`, `low`, `medium`, `high` or `critical`. Findings below it are not shown, not written to the report and do not affect the exit code. `info` is only used for findings downgraded by a [permission guard](#guards). |
| `fail-on` | string | `"low"` | Exit with code `1` when a reported finding has at least this severity. `low` means any reported finding except `info` fails; `never` always exits `0` (unless there is an error). |
| `project` | string | `default.project.json` when it exists | Rojo project file used to map files to instances (`ServerScriptService`, `ReplicatedStorage`, ...). This decides where code runs: see [Where code runs](analysis.md#1-where-code-runs). Without a project, directory names are used as hints. |
| `ignore` | array of globs | `[]` | Files and directories that are not analysed. Globs are relative to the directory of the configuration file: `*` matches inside one path segment, `**` matches any number of directories. Directories named `Packages`, `DevPackages`, `ServerPackages`, `node_modules` and `.git` are always skipped. |
| `trust-unresolved-validators` | boolean | `true` | When a guard calls a function that cannot be resolved and whose name starts with `is`, `validate`, `verify`, `check`, `sanitize`, `assert` or `ensure` (for example `Validator.isValidItem(x)` from a package), trust it to validate its arguments. Set to `false` to require real checks or [sanitizers](#sanitizers). |
| `max-call-depth` | integer | `6` | How many nested calls into local functions and required modules are followed. A deeper call is replaced by a summary of the function, made once with placeholder arguments: what it returns in terms of its parameters, with the checks it made (see [analysis](analysis.md#3-propagation)). A function that cannot be summarised (recursive, variadic, over budget) is cut off: its result carries the client data of its arguments, unchecked. |
| `allow-parse-errors` | boolean | `false` | A file that cannot be read or parsed is skipped with a warning, and by default the run then exits with code `2`, because the file was not analysed. Set to `true` (or pass `--allow-parse-errors`) to only warn. |

How `min-severity` and `fail-on` combine (exit code `2` always means a usage,
configuration or I/O error, or a file that could not be analysed):

| `min-severity` | `fail-on` | Reported | Exit code `1` when |
| --- | --- | --- | --- |
| `low` | `low` (defaults) | everything | any finding |
| `low` | `high` | everything | a high or critical finding |
| `medium` | `low` | medium and above | any reported finding |
| `high` | `critical` | high and critical | a critical finding |
| `low` | `never` | everything | never |

## Rules

The `[rules]` table turns rules on and off and changes their severity. Keys
are rule ids; rules that are not listed run with their default severity.

| Rule | Name | Default severity |
| --- | --- | --- |
| [luau-shield001](rules/luau-shield001.md) | untrusted-economy-write | high |
| [luau-shield002](rules/luau-shield002.md) | untrusted-instance-property | high |
| [luau-shield003](rules/luau-shield003.md) | unverified-client-instance | high |
| [luau-shield004](rules/luau-shield004.md) | untrusted-code-execution | critical |
| [luau-shield005](rules/luau-shield005.md) | untrusted-http-request | high |
| [luau-shield006](rules/luau-shield006.md) | server-invokes-client | medium |
| [luau-shield007](rules/luau-shield007.md) | remote-without-rate-limit | low |
| [luau-shield008](rules/luau-shield008.md) | client-exposed-secret | critical |

`luau-shield rules` prints the same list.

Each value is one of:

| Value | Effect |
| --- | --- |
| `"off"` | The rule does not run. |
| `"on"` | The rule runs with its default severity. |
| `"info"`, `"low"`, `"medium"`, `"high"`, `"critical"` | The rule runs with this severity (`"info"` hides it unless `min-severity = "info"`). |
| `{ enabled = true, severity = "medium" }` | Table form of the two settings; both keys are optional. |

```toml
[rules]
luau-shield006 = "high"                                  # treat InvokeClient on the server as high
luau-shield007 = "off"                                   # rate limiting is enforced elsewhere
luau-shield002 = { enabled = true, severity = "critical" }
```

A changed severity is used everywhere: for `min-severity`, for `fail-on` and
in the text, JSON and SARIF reports.

## Function patterns

Sanitizers, sinks and sources select functions with a `function` pattern,
matched against the callee **as it is written in the code**:

| Pattern | Matches |
| --- | --- |
| `"isValid"` | `isValid(x)` |
| `"Validate.amount"` | `Validate.amount(x)` and `Validate:amount(x)` |
| `"Guard:check"` | `Guard:check(x)` and `Guard.check(x)` |
| `"*.amount"` | `Validate.amount(x)`, `V.amount(x)`, ... (`*` matches exactly one path segment) |
| `"*.Client.*"` | `ShopService.Client.Buy`, `ShopService.Client:Buy`, ... |

`:` and `.` are equivalent. Because the pattern is matched against the code
as written, a module required under another local name
(`local V = require(ReplicatedStorage.Shared.Validate)`) is called as
`V.amount(x)`: use `"V.amount"` or `"*.amount"`.

## Sanitizers

A sanitizer is one of your own validation functions. luau-shield already
analyses validation functions that live in the checked files or in modules it
can resolve (see [Validation functions](analysis.md#validation-functions)).
Declare a sanitizer when it cannot: the function comes from a package that is
not analysed (`Packages/` is always skipped), it is built dynamically, or you
want to state exactly what it guarantees.

```toml
[[sanitizers]]
function = "Validate.amount"
checks = ["type", "lower", "upper", "nan"]
```

| Key | Type | Default | Meaning |
| --- | --- | --- | --- |
| `function` | string | required | [Function pattern](#function-patterns). |
| `checks` | `"all"` or array | `"all"` | Facts that hold for the protected value. `"all"` means *validated*: the value is safe for every rule. |

A sanitizer protects a value in two ways:

- **As a guard.** When the call decides whether execution continues, its
  arguments get the facts for the code that runs after the guard succeeds:

  ```lua
  if not Validate.amount(amount) then return end
  assert(Validate.amount(amount), "bad amount")
  ```

- **Through its return value.** The returned value carries the facts; the
  original variable is unchanged:

  ```lua
  local clean = Validate.amount(amount)
  coins.Value += clean -- protected
  ```

The facts you can list in `checks` are the ones described in
[Checks](analysis.md#4-checks-sanitizers):

| Fact | Stands for a check like |
| --- | --- |
| `"type"` | `typeof(x) == "number"` |
| `"lower"` | `x >= 1` |
| `"upper"` | `x <= 100` |
| `"nan"` | `x == x` (NaN rejected) |
| `"allowlist"` | `ITEMS[x] ~= nil`, `table.find(ALLOWED, x)` |
| `"pattern"` | `x:match("^%w+$")` (anchored at both ends) |
| `"length"` | `#x <= 50` |
| `"ownership"` | `x:IsDescendantOf(player.Character)`, distance checks |
| `"filtered"` | `TextService:FilterStringAsync(...)` + `GetNonChatStringForBroadcastAsync()` |
| `"encoded"` | `HttpService:UrlEncode(x)` |

Which facts are enough depends on the rule:

| Rule | Enough |
| --- | --- |
| luau-shield001 | `allowlist`; numbers: `type` + `lower` + `upper` + `nan`; strings: `type` + `length`, or `pattern` |
| luau-shield002 | `allowlist`; `lower` + `upper`; `Parent`, `Team`, `RespawnLocation`, `PrimaryPart`: `ownership`; `Text`: `filtered` |
| luau-shield003 | `ownership` or `allowlist` |
| luau-shield004 | `allowlist` |
| luau-shield005 | URL: `allowlist`, `pattern` or `encoded`; body and headers: the same, or `type` + `length`, or `filtered` |

When in doubt, keep the default `checks = "all"`; list facts only when the
function really checks less than everything.

luau-shield tells you when a sanitizer declaration may be missing. When the
value of a finding comes out of a function named like a sanitizer (its name
contains `sanitize`, `validate`, `clean`, `normalize`, `verify`, `check`,
`coerce`, `clamp`, `filter`, `safe`, `parse` or `strict`) that luau-shield
could not follow, or whose checks it could not prove on every path, the fix of
the finding ends with a suggestion such as:

```text
The value comes from `Look.sanitize`, which luau-shield could not follow: if
`Look.sanitize` validates it, declare it as a sanitizer (`[[sanitizers]]` with
`function = "Look.sanitize"` in luau-shield.toml).
```

Before you do, read the function: the declaration makes luau-shield trust it
completely.

## Guards

Admin tools legitimately let some players set values: an admin panel that
sets a player's coins, a `;give` chat command. When code only runs after a
**permission check on the player who sent the request** succeeds, findings in
that code are reported with severity `info` and the message ends with
`(admin only: after Admins.isAdmin(sender))`. `info` is below the default
`min-severity`, so these findings are hidden unless you ask for them with
`--min-severity info`:

```lua
local function onCommand(sender, text)
	if not Admins.isAdmin(sender) then return end
	data[sender].Coins += tonumber(text) or 0 -- info: admin only
end
```

A permission check is one of:

- **A call to a guard function** on the sender:
  - the function's name (the last segment: `Admins.isAdmin`, `is_admin`) is
    a built-in name, ignoring case and underscores: `isAdmin`,
    `isSuperAdmin`, `isHeadAdmin`, `isGameOwner`, `isCreator`,
    `isModerator`, `isMod`, `isStaff`, `isDeveloper`, `isDev`, `hasAdmin`,
    `hasAdminRights`, `hasAdminAccess`, `hasAdminPermission(s)`,
    `hasPermission(s)`. When it is called on a module, the module's name
    must say so (it contains `admin`, `perm`, `staff`, `moder`, `rank`,
    `role`, `auth`, `access`, `whitelist`, `command`, `cmd` or
    `privilege`): `clan:isModerator(player)` or `plot:hasPermission(player,
    "Build")` are about a clan or a plot, not about who the player is.
    `isOwner` is not built in (tycoons, plots and pets have owners); add it
    to `functions` if it means the game owner in your code;
  - or it matches a pattern in `[guards] functions` (any module name);
  - one argument is the sender (`player`, `player.UserId` or `player.Name`;
    not `player.DisplayName`, which players choose) and every other
    argument is a constant (`hasPermission(player, "Ban")`). A check on a
    player chosen by the client (`isAdmin(target)`) or on another object
    (`isOwner(player, plot)`) is not a permission check;
  - the call itself is the condition (`if not Admins.isAdmin(player)`,
    `assert(...)`, `local ok = Admins.isAdmin(player)`), or is compared with
    `true`. `isAdmin(player) ~= nil` and `isAdmin(player) == false` do not
    count: they also hold when the function returns `false` or `nil` for
    other players;
  - inside a service, `self:isAdmin(player)` (and Knit's
    `self.Server:isAdmin(player)`) is named after the table the method is
    declared on (`AdminService:isAdmin`);
  - the module must not be chosen by the client
    (`ClanRoles[clanId]:isModerator(player)` is not a permission check).
- **A permission level** returned by a guard function and compared with a
  server value: `Admin.getLevel(player) >= 2`, `getRank(player) <
  command.rank` (then the code after it is admin only). A constant
  threshold must be at least 1 (level 0 is everybody). Declare your level
  functions in `functions`.
- **An inline check** on the sender (built in, see `defaults`):
  - `player.UserId == game.CreatorId` or `player.UserId == 12345`;
  - `player:GetRankInGroup(GROUP) >= 250` (also `> N`, `== N`, or the
    reject forms `< N` and `~= N`, and through a local holding the rank):
    the group must be a constant and the lowest rank that passes at least 2
    (rank 1 is any member of the group, rank 0 anybody);
  - `player:GetRoleInGroup(GROUP) == "Admin"`, with a constant group and a
    role name that contains `owner`, `admin`, `moder`, `staff`, `developer`,
    `creator` or `founder`;
  - `ADMINS[player.UserId]` or `table.find(ADMIN_IDS, player.UserId)` (also
    through a local, or compared with `nil`) with a server table whose name
    contains `admin`, `moder`, `staff` or `developer`. Not `owner` (every
    player owns a plot or a tycoon, game pass owners are players) nor
    `whitelist` (beta testers). The table must not be picked with a key the
    client sends (`clanAdmins[clanId]`), and no remote handler may write
    client data into it: a list the client can add itself to proves
    nothing, and the findings that relied on it are reported at their
    normal severity.

Findings of luau-shield001, 002, 003, 005 and 007 behind such a check are
downgraded. So are a `player.Chatted` listener connected only after the
check, for the player who passed it (a listener on another player, such as
the target of an admin tool, gets that player's messages), and `...` of the
handler itself. A function or callback reached from both an admin handler
and a public one is analysed for both: its findings in the public one are
not downgraded. Two kinds are never downgraded:

- code execution (luau-shield004): a stolen admin account or a wrong asset
  id would run arbitrary code on the server;
- unfiltered text shown to other players (luau-shield002 on `Text`): Roblox
  requires filtering whoever typed it.

```toml
[guards]
functions = ["Staff.canModerate", "PermissionService:Check"]
defaults = true
```

| Key | Type | Default | Meaning |
| --- | --- | --- | --- |
| `functions` | array of [function patterns](#function-patterns) | `[]` | Your own permission checks. A pattern with a single name (`"canModerate"`) matches that name on any receiver. |
| `defaults` | boolean | `true` | Also trust the built-in names and the inline checks above (creator id, group rank and role, permission lists). Set to `false` if one of them does not check permissions in your code; then only `functions` count. |

## Sinks

A sink is a function that must not receive client data, typically a wrapper
around something sensitive that luau-shield cannot see through (a currency
service in a package, a data layer such as ProfileStore wrappers, an admin
API).

```toml
[[sinks]]
function = "Economy.addCoins"   # Economy.addCoins(player, amount)
rule = "luau-shield001"
arguments = [2]
```

| Key | Type | Default | Meaning |
| --- | --- | --- | --- |
| `function` | string | required | [Function pattern](#function-patterns). |
| `rule` | string | required | Rule the finding is reported under. The value must pass the same checks as that rule's built-in sinks (for `luau-shield001`: allow-listed, validated, or a number with lower and upper bounds and NaN rejected, ...). |
| `arguments` | array of integers | all arguments | 1-based positions that must not receive client data. For a method call written with `:`, `self` is not counted: in `PlayerData:set(player, key, value)`, `value` is argument `3`. |

The finding is reported on the line of the call.

## Sources

A source declares functions whose parameters come from the client, for remote
frameworks where handlers are declared by name instead of connected to
`OnServerEvent`. Knit-style client methods (`function Service.Client:Method(player, ...)`)
are built in as `"*.Client.*"`.

```toml
[[sources]]
function = "*.Remotes.*"   # function ShopService.Remotes.Buy(player, itemId)
trusted-parameters = 1
```

| Key | Type | Default | Meaning |
| --- | --- | --- | --- |
| `function` | string | required | [Function pattern](#function-patterns) matched against the name in the function declaration. |
| `trusted-parameters` | integer | `1` | Number of leading parameters (after `self`) that are trusted, usually the player. Every later parameter is client-controlled. |

## Explain

`luau-shield check --explain` asks a local [Ollama](https://ollama.com) server
to explain each finding in plain words. Nothing is sent anywhere else.

```toml
[explain]
model = "qwen2.5-coder:7b"
timeout-seconds = 60
```

| Key | Type | Default | Meaning |
| --- | --- | --- | --- |
| `model` | string | `"qwen2.5-coder:7b"` | Ollama model. `--ollama-model` overrides it. |
| `timeout-seconds` | integer | `60` | Time allowed for each explanation. |

The server address comes from the `OLLAMA_HOST` environment variable
(default `http://localhost:11434`).

## Suppressing findings

When a finding is wrong, or the risk is accepted, suppress it in the code
with a comment that names the rule. Always write the reason: it is what the
next reviewer reads.

**One line.** Put the comment at the end of the line of the finding, or on
the line directly above it:

```lua
coins.Value += amount -- luau-shield-ignore: luau-shield001 amount is validated by the shop module

-- luau-shield-ignore: luau-shield003 doors are registered and checked by DoorRegistry
door.CanCollide = false
```

**A whole file.** Put the comment at the top of the file:

```lua
-- luau-shield-ignore-file: luau-shield007 admin remotes, only callable by group admins
```

The rule list is optional: a bare `-- luau-shield-ignore` (or
`-- luau-shield-ignore-file`) suppresses every rule on that line (or file).
Prefer naming the rule, so that a new kind of problem on the same line is
still reported.

Suppressed findings are not reported and do not affect the exit code, but
they are counted in the summary, so suppressions stay visible.

The comment goes on the line where the finding is reported:

| Rule | Line of the finding |
| --- | --- |
| luau-shield001, luau-shield002, luau-shield005 | the assignment or the method call (the sink) |
| luau-shield003 | the first statement that uses the unverified Instance |
| luau-shield004 | the `loadstring` / `require` / dynamic lookup call |
| luau-shield006 | the `:InvokeClient(` call or the `OnClientInvoke =` assignment |
| luau-shield007 | the line containing `OnServerEvent` / `OnServerInvoke` |
| luau-shield008 | the line of the string literal |

For example, to accept a handler without a rate limit:

```lua
-- luau-shield-ignore: luau-shield007 called at most once per round by the game loop
remotes.ReadyUp.OnServerEvent:Connect(function(player)
	readyPlayers[player] = true
end)
```

## Examples

### A Knit project

A Rojo + Wally project using [Knit](https://github.com/Sleitnick/Knit):
`src/server` is mapped to `ServerScriptService`, `src/shared` to
`ReplicatedStorage`, and the services validate their arguments with a private
Wally package, `Validators`, that lives in `Packages/` and is therefore not
analysed.

```lua
-- src/server/Services/ShopService.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Validators = require(ReplicatedStorage.Packages.Validators)

local PRICES = { Sword = 100, Shield = 150 }

local ShopService = Knit.CreateService({ Name = "ShopService", Client = {} })

-- Knit client methods are sources out of the box: itemId and quantity are untrusted.
function ShopService.Client:Buy(player, itemId, quantity)
	local price = PRICES[itemId]
	if not price then return false end
	local count = Validators.count(quantity) -- type, bounds and NaN checked
	local coins = player.leaderstats.Coins
	if coins.Value < price * count then return false end
	coins.Value -= price * count
	return true
end

return ShopService
```

```toml
# luau-shield.toml, next to default.project.json
project = "default.project.json"
fail-on = "medium"
ignore = ["**/*.spec.luau", "src/server/Dev/**"]

[rules]
luau-shield006 = "high"   # we never want InvokeClient on the server

# Validators comes from Packages/, which is never analysed: declare what it guarantees.
[[sanitizers]]
function = "Validators.count"     # integer between 1 and 99, errors otherwise
checks = ["type", "lower", "upper", "nan"]

[[sanitizers]]
function = "Validators.itemId"    # must be a key of the item catalog
checks = ["allowlist"]

[[sanitizers]]
function = "Validators.ownedTool" # Tool inside the player's Backpack or Character
checks = ["ownership"]

# Some older services expose handlers as Service.Remotes.<Name>(player, ...).
[[sources]]
function = "*.Remotes.*"
trusted-parameters = 1
```

### A project with its own validation library

The game keeps validation and sensitive operations in shared modules that are
loaded through a custom loader, so luau-shield cannot resolve the `require`
calls. The configuration describes the validators and declares the economy
and data functions as sinks.

```lua
-- How the modules are used in the server code.
local Validate = Loader.get("Validate")
local Economy = Loader.get("Economy")
local PlayerData = Loader.get("PlayerData")

remotes.Sell.OnServerEvent:Connect(function(player, itemName, amount)
	if not Validate.itemName(itemName) then return end
	if not Validate.amount(amount) then return end
	Economy.addCoins(player, amount)
	PlayerData:set(player, "LastSold", itemName)
end)
```

With the configuration below this handler produces no finding. Without the
`Validate.amount` guard, luau-shield reports luau-shield001 on the `Economy.addCoins`
line.

```toml
# luau-shield.toml
project = "default.project.json"
min-severity = "low"
fail-on = "high"
# Only trust validators that are declared below or analysed from source.
trust-unresolved-validators = false
max-call-depth = 8

[[sanitizers]]
function = "Validate.amount"      # number, 1 <= x <= 1e6, NaN rejected
checks = ["type", "lower", "upper", "nan"]

[[sanitizers]]
function = "Validate.itemName"    # key of the item catalog
checks = ["allowlist"]

[[sanitizers]]
function = "Validate.chatText"    # filtered with TextService
checks = ["filtered"]

[[sanitizers]]
function = "Validate.payload"     # full schema validation
checks = "all"

[[sinks]]
function = "Economy.addCoins"     # Economy.addCoins(player, amount)
rule = "luau-shield001"
arguments = [2]

[[sinks]]
function = "PlayerData:set"       # PlayerData:set(player, key, value)
rule = "luau-shield001"
arguments = [2, 3]

[[sinks]]
function = "Admin.run"            # Admin.run(player, commandSource)
rule = "luau-shield004"
arguments = [2]
```

### A strict CI setup

A configuration used only in CI: every finding fails the build, nothing is
trusted on name alone, rate limiting and `InvokeClient` count more, and test
and story files are skipped. It lives at the repository root under another
name, so it is never picked up by discovery and only applies when passed with
`--config`.

```toml
# luau-shield.ci.toml
min-severity = "low"
fail-on = "low"
project = "default.project.json"
ignore = ["**/*.spec.luau", "**/*.story.luau", "tools/**"]
trust-unresolved-validators = false
max-call-depth = 10

[rules]
luau-shield006 = "high"
luau-shield007 = { enabled = true, severity = "medium" }
```

```sh
luau-shield check src --config luau-shield.ci.toml --format sarif --output luau-shield.sarif
```

Developers keep the default (or a more relaxed) `luau-shield.toml` for local
runs; CI passes `--config luau-shield.ci.toml`. In
GitHub Actions, pass the file with the action's `config` input and remember
that the action's own `min-severity` and `fail-on` inputs override the file
(see [CI integration](ci.md)).
