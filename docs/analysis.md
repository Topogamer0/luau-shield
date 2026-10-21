# How the analysis works

luau-shield is a static **taint analyzer**. It does not grep for suspicious
strings: it parses every Luau file into a syntax tree (with
[full-moon](https://github.com/Kampfkarren/full-moon)), then abstractly
executes the server code, tracking which values come from the client, how they
flow through variables, tables and function calls, which checks they pass, and
where they end up.

This page describes exactly what the analyzer understands. If your project uses
a pattern that is not listed here, you can teach it with
[custom sanitizers, sinks and sources](configuration.md).

## 1. Where code runs

Every file gets a *run context*:

| File | Context |
| --- | --- |
| `*.server.luau` / `*.server.lua` (Script) | server |
| `*.client.luau` / `*.client.lua` (LocalScript) | client |
| ModuleScript under `ServerScriptService` or `ServerStorage` | server module |
| ModuleScript under `ReplicatedStorage`, `ReplicatedFirst`, `StarterPlayer`, `StarterGui`, `StarterPack`, `Workspace` | replicated module (runs on both sides, **source is visible to clients**) |
| anything else | unknown |

The location of a file comes from the Rojo project (`default.project.json`, or
the file passed with `--project`). Without a project file, directory names are
used as hints: a path component named `server`, `ServerScriptService` or
`ServerStorage` means server; `client`, `StarterPlayer`, `StarterPlayerScripts`,
`StarterCharacterScripts`, `StarterGui`, `StarterPack`, `ReplicatedFirst` means
client; `shared`, `common` or `ReplicatedStorage` means replicated module
(matching is case-insensitive).

Server-side rules (LS001–LS007) never run on client files: a LocalScript that
changes `leaderstats` only changes the local copy. LS008 (secrets) only runs on
code whose source is sent to clients.

## 2. Sources of untrusted data

| Source | Untrusted values |
| --- | --- |
| `remote.OnServerEvent:Connect(function(player, ...) end)` (also `:Once`, `:ConnectParallel`; `RemoteEvent` and `UnreliableRemoteEvent`) | every parameter after `player` |
| `remote.OnServerInvoke = function(player, ...) end` | every parameter after `player` |
| `local result = remote:InvokeClient(player, ...)` | the values returned by the client |
| `player.Chatted:Connect(function(message) end)` | `message` |
| Knit-style client methods: `function Service.Client:Method(player, ...)` | every parameter after `player` |
| [custom sources](configuration.md#sources) | configurable |

The first parameter (`player`) is filled in by the engine and can be trusted.
Handlers may be inline functions, local functions, module functions, or
functions stored in a table and connected in a loop.

**Type annotations are not checks.** `function(player, amount: number)` still
receives whatever the exploiter sends: Luau types are erased at runtime.

## 3. Propagation

A value derived from untrusted data is untrusted. Taint flows through:

- local variables, assignments, multiple assignment, compound assignment
  (`+=`, `..=`, ...);
- arithmetic, concatenation (`..`), string interpolation, `if`-expressions,
  `and`/`or`, type assertions (`x :: number`), parentheses;
- table constructors and fields: `{ amount = x }`, `data.amount`, `data[k]`,
  nested tables, `table.insert`, `{...}`, `select`, `table.unpack`;
- string library functions (`string.format`, `s:sub()`, `s:lower()`, ...),
  `tostring`, `tonumber`, `math.*`, `HttpService:JSONEncode/JSONDecode`;
- calls to **local functions of the same file** (the callee is analysed with
  the tainted arguments, so sinks inside helpers are found and return values
  carry the taint back);
- calls to functions of **required modules** when the `require` path can be
  resolved statically: `require(script.Parent.Economy)`,
  `require(game:GetService("ServerScriptService").Modules.Economy)`,
  `require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"))`,
  `require("./Economy")` and `.luaurc` aliases (`require("@shared/Util")`).
  Instance paths are mapped to files through the Rojo project tree;
- calls to unknown functions: the result is conservatively considered tainted
  if any argument is tainted.

Reading a value out of a **server-owned** table with an untrusted key does
*not* produce untrusted data: `PRICES[itemId]` is a server value (it may be
`nil`, but the client cannot choose its contents). The same applies to
lookups such as `folder:FindFirstChild(name)` or
`Players:GetPlayerByUserId(id)`.

Reading a field of a value sent by the client (`data.amount`) is untrusted:
remotes can carry arbitrary tables.

## 4. Checks (sanitizers)

The analyzer is flow-sensitive: it understands `if` statements, early
`return`, `error(...)`, `assert(...)`, `if`-expressions and `and`/`or` guards.
A check only protects the code that runs *after it succeeds*. For example all
of these protect `amount` for the rest of the handler:

```lua
if typeof(amount) ~= "number" then return end
assert(typeof(amount) == "number", "bad amount")
if not isValidAmount(amount) then player:Kick() return end
```

A value accumulates *facts*. Each rule decides which facts are enough
(see the rule pages). The facts are:

| Fact | Established by |
| --- | --- |
| **type** | `typeof(x) == "number"`, `type(x) == "string"`, `x:IsA("BasePart")` (Instance), `tonumber(x)` (number), `tostring(x)` (string), `t.number(x)` and other [`t`](https://github.com/osyrisrblx/t) checks |
| **lower bound** | `x > c`, `x >= c`, `math.max(x, c)`, `math.clamp(x, a, b)` (where `c` is server data) |
| **upper bound** | `x < c`, `x <= c`, `math.min(x, c)`, `math.clamp(x, a, b)`, `#x <= c` (length of strings/tables) |
| **NaN rejected** | `x == x`, `x ~= x` → reject, or a comparison that must be **true** for execution to continue (`if x > 0 and x <= 100 then ... end`). Comparisons that must be *false* (`if x <= 0 or x > 100 then return end`) do **not** reject NaN, because every comparison with NaN is false. `math.clamp`, `math.min` and `math.max` return NaN for NaN. |
| **allow-listed** | `x == "literal"`, `ALLOWED[x]` truthy (server table), `table.find(ALLOWED, x)`, `ALLOWED[x] ~= nil`, `folder:FindFirstChild(x)` non-nil |
| **pattern** | `string.match(x, "^...$")` / `x:match("^%w+$")` with a pattern anchored at both ends |
| **length** | `#x <= c` / `#x < c` / `string.len(x) <= c` |
| **ownership / location** (Instances) | `x:IsDescendantOf(...)`, `y:IsAncestorOf(x)`, `x.Parent == ...`, `x:FindFirstAncestor...(...) == ...`, `Players:GetPlayerFromCharacter(...) == player`, `x:GetAttribute("Owner") == player.UserId`, `x.Owner.Value == player`, distance checks such as `(x.Position - root.Position).Magnitude <= 10` or `player:DistanceFromCharacter(x.Position) < 10` |
| **filtered text** | the result of `TextService:FilterStringAsync(...)` + `GetNonChatStringForBroadcastAsync()` / `GetChatForUserAsync()` / `GetNonChatStringForUserAsync()`, `Chat:FilterStringForBroadcast(...)` |
| **url-encoded** | `HttpService:UrlEncode(x)` |
| **validated** (everything) | a call to a [custom sanitizer](configuration.md#sanitizers), or a validation function analysed by luau-shield (see below) |

A boolean value that passed a type check (`typeof(x) == "boolean"`) is always
considered safe: there are only two possible values.

Checkers built with the [`t`](https://github.com/osyrisrblx/t) library give the
facts of the checkers they are made of: `t.number` gives *type*,
`t.numberConstrained(1, 100)` gives *type + bounds + NaN rejected* (it compares
with `>=`/`<=` in a must-be-true form), `t.integer` rejects NaN,
`t.literal(...)`/`t.keyOf(...)`/`t.valueOf(...)` allow-list, `t.instanceIsA(...)`
gives *type Instance*. `t.tuple(a, b)` applies `a` to the first argument and `b`
to the second, `t.strictInterface({ amount = t.number })` checks the fields, and
`t.strict(check)` turns a checker into an assertion:

```lua
local checkBuy = t.tuple(t.string, t.numberConstrained(1, 99))
if not checkBuy(itemId, quantity) then return end
-- itemId: type string; quantity: type number, bounds, NaN rejected
```

### Validation functions

When a guard calls a function defined in the same file or in a resolved module,
luau-shield analyses that function and works out which facts hold for its
arguments whenever it returns a truthy value:

```lua
local function isValidAmount(n: unknown): boolean
	return typeof(n) == "number" and n == n and n >= 1 and n <= 1000
end

remote.OnServerEvent:Connect(function(player, amount)
	if not isValidAmount(amount) then return end
	-- amount: type number, bounds [1, 1000], NaN rejected
end)
```

If the function cannot be resolved (for example it comes from a package that
is not part of the checked tree), a guard calling a function whose name starts
with `is`, `validate`, `verify`, `check`, `sanitize`, `assert` or `ensure`
(for example `Validator.isValidItem(x)`) is trusted to validate its arguments.
This keeps false positives low; disable it with
`trust-unresolved-validators = false` in the configuration.

## 5. Sinks

Each rule has its own sinks and its own idea of "checked enough":

| Rule | Sink | Required facts |
| --- | --- | --- |
| [LS001](rules/LS001.md) | currency/stats/leaderstats writes, persistent data writes, DataStore/MemoryStore writes | allow-listed, validated, boolean, or *type number + lower bound + upper bound + NaN rejected* (strings: type + length or pattern) |
| [LS002](rules/LS002.md) | sensitive Instance properties (`Position`, `CFrame`, `Health`, `WalkSpeed`, `Parent`, `Text`, ...) and methods (`PivotTo`, `TakeDamage`, `ApplyImpulse`, `SetAttribute`, ...) | allow-listed, validated, boolean, or lower + upper bound (`Parent`: ownership; `Text`: filtered) |
| [LS003](rules/LS003.md) | an Instance sent by the client that is modified, destroyed, cloned, moved or whose data is used | ownership/location, allow-listed or validated |
| [LS004](rules/LS004.md) | `loadstring`, `load`, `require`, `getfenv()[x]`, `_G[x]` | allow-listed or validated |
| [LS005](rules/LS005.md) | `HttpService:GetAsync/PostAsync/RequestAsync` URL, headers and body | URL: allow-listed, pattern, url-encoded, number, validated. Body: same, or type string + length, or filtered |
| [LS006](rules/LS006.md) | `RemoteFunction:InvokeClient` on the server outside a detached thread; `OnClientInvoke` assigned in server code | — |
| [LS007](rules/LS007.md) | remote handlers doing expensive work (`*Async` calls, `Instance.new`, `:Clone()`) without a rate limit | a rate limit (see the rule page) |
| [LS008](rules/LS008.md) | hard-coded webhooks, API keys and tokens in code replicated to clients | — |

## 6. Limits

Static analysis is an approximation and can be wrong in both directions:

- **Dynamic code cannot be followed**: `getfenv`, `setmetatable` tricks,
  `loadstring`, functions selected at runtime by string keys, values passed
  through `BindableEvent`s, attributes or `ValueBase` objects, coroutines and
  signals libraries are not tracked.
- `require` paths that are computed at runtime are not resolved; calls into
  unresolved modules propagate taint conservatively.
- Tables are tracked by value: aliasing (two variables pointing to the same
  table) is approximated.
- Loops are analysed a bounded number of times; recursion and deeply nested
  calls are cut off (default depth: 6).
- The heuristics that recognise "currency", "stats" and "DataStore" objects
  rely on names (`leaderstats`, `Coins`, `Cash`, `GetDataStore`, ...).
- A check that is present but wrong (for example a bound that is too large)
  is considered a check.

When the analyzer is wrong, suppress the finding with a comment and a reason:

```lua
coins.Value += amount -- luau-shield-ignore: LS001 amount is validated by the shop module
```
