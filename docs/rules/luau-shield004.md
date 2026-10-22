# luau-shield004: untrusted-code-execution

A value controlled by the client reaches a function that compiles or looks up
code to run (`loadstring`, `load`, `require`, `getfenv()[x]`, `_G[x]`,
`shared[x]`), so the client decides *what code runs on the server*.

| Severity | Default | Applies to |
| --- | --- | --- |
| critical | enabled | server code: Scripts, server modules and every module they reach (replicated or of unknown context); never `*.client.luau` LocalScripts or modules in client folders |

## What it detects

luau-shield004 follows values that come from the client (the parameters of
`OnServerEvent` / `OnServerInvoke` handlers after `player`, values returned by
`InvokeClient`, `player.Chatted` messages, Knit `Client` methods: see
[Sources of untrusted data](../analysis.md#2-sources-of-untrusted-data))
through variables, tables, local functions and required modules
([Propagation](../analysis.md#3-propagation)). It reports a finding when such a
value reaches one of the sinks below without being
[allow-listed or validated](#what-counts-as-a-check).

The sinks are the ways Luau turns data into executable code:

1. **Compiling a string.** `loadstring(x)` and `load(x)` compile `x` into a
   function. The client-controlled value may be the whole chunk or any part of
   a concatenation / interpolation that builds it:

   ```lua
   local chunk = loadstring(source)
   local evaluate = loadstring("return " .. expression)
   ```

2. **Requiring by a client value.** `require(x)` where `x` is client-controlled
   — most dangerously an asset id (`require(assetId)`), which fetches and runs
   an arbitrary public `ModuleScript` on the server. This is the classic
   backdoor-installation vector.

3. **Dynamic global lookup.** Calling a function selected by a client-controlled
   key out of the script environment or a global table:
   `getfenv()[name](...)`, `_G[name](...)`, `shared[name](...)`. The client can
   reach any global the environment exposes (including `require`, `loadstring`
   and `setfenv`) or any function another script stored in `_G` / `shared`.

`player.Chatted` is a source, so a `/run <code>` chat command that reaches
`loadstring` is detected even though it never touches a remote. The finding is
reported on the sink line: the `loadstring` / `load` / `require` call, or the
dynamic-lookup call. When the sink is inside a helper or a required module, the
finding is on that call, with the client value supplied by the handler that
reached it.

**Not a sink: dispatch through a server table.** Calling a function stored in a
developer-written table by a client-chosen key — `Commands[name](player)` — is
an allow-list dispatch, not dynamic execution: only the functions you put in the
table can run, and an unknown key yields `nil`. luau-shield004 does not report it.
The same holds for `require` of a `ModuleScript` **value** read from a server
table (`require(WEAPON_MODULES[name])`): the key is the client's, but the value
is yours.

**Not a sink: calling a field of client data.** Remotes cannot carry
functions, so `data.callback()` or `pcall(name.upper, name)` cannot run a
function the client chose (at worst the call errors). They are not reported.

## Why it is dangerous

A server that runs client-supplied code hands the exploiter the whole game. An
executor fires the remote with any string it likes, and that string runs with
full server privileges:

```lua
-- Run by the exploiter in their executor, not by your game.
local remotes = game:GetService("ReplicatedStorage").Remotes
remotes.RunCode:FireServer("game:GetService('Players'):ClearAllChildren()")
remotes.RunCode:FireServer("require(0000000):backdoor()") -- load a remote module
```

From there they can wipe the map, hand themselves currency and items, read and
overwrite every player's DataStore, kick or ban at will, and persist all of it.
`require(assetId)` is just as bad without a single line of injected text: the
exploiter points it at a `ModuleScript` they published, and your server runs it
on every call. An `_G[name]` or `getfenv()[name]` dispatch is a narrower door
but still a door — the client can call `loadstring`, `require` or any privileged
global the environment holds.

Guarding these calls with a *player* check (an admin id, a group rank) does not
close the hole: it only decides *who* may send code, not *what* the code does.
If the check is ever wrong, or a trusted account is compromised, it is remote
code execution. luau-shield004 therefore reports an owner-only console too; keep it
only if you accept that risk and [suppress it](#suppressing) with a reason.

## Vulnerable example

```lua
-- ServerScriptService/Console.server.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunCode = ReplicatedStorage.Remotes.RunCode :: RemoteEvent

local OWNER_ID = 123456789

RunCode.OnServerEvent:Connect(function(player: Player, source: string)
	if player.UserId ~= OWNER_ID then
		return -- only the owner may send code...
	end
	-- ...but `source` itself is never constrained, so this is still RCE.
	local chunk = loadstring(source) -- luau-shield004
	if chunk then
		chunk()
	end
end)
```

The owner check protects nothing about the *value*: `source` is still an
arbitrary string chosen by whoever fires the remote. luau-shield004 reports it.

## Fixed example

Do not accept code. Let the client choose the *name* of an action and run a
server-written function from a fixed table:

```lua
-- ServerScriptService/Console.server.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunCommand = ReplicatedStorage.Remotes.RunCommand :: RemoteEvent

-- The client picks a NAME; the code that runs is server-written.
local COMMANDS: { [string]: (player: Player) -> () } = {
	respawn = function(player)
		player:LoadCharacter()
	end,
	heal = function(player)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = humanoid.MaxHealth
		end
	end,
}

RunCommand.OnServerEvent:Connect(function(player: Player, name: string)
	local command = COMMANDS[name]
	if not command then
		return -- unknown name: nothing runs
	end
	command(player)
end)
```

`COMMANDS[name]` is a value read from a server table, and calling it is an
allow-list dispatch — only `respawn` and `heal` can ever run, whatever `name`
is. luau-shield004 is satisfied.

When you genuinely must load a module chosen at runtime, allow-list the id
against a vetted set before `require`:

```lua
local APPROVED_PLUGINS = { 1234567, 2345678, 3456789 }

LoadPlugin.OnServerEvent:Connect(function(player: Player, assetId: number)
	if not table.find(APPROVED_PLUGINS, assetId) then
		return -- from here on, assetId is allow-listed
	end
	local plugin = require(assetId)
	plugin.init(player)
end)
```

## What counts as a check

Unlike the economy and property rules, luau-shield004 does **not** care about the
magnitude or type of a value — a number bound or a length limit tells you
nothing about which code will run. Only two kinds of fact make a client value
safe for this rule (see [Checks](../analysis.md#4-checks-sanitizers)), and only
for code that runs *after* the check succeeds:

- **allow-listed** — the value is constrained to a fixed, server-defined set:

  ```lua
  if name ~= "respawn" and name ~= "heal" then return end     -- literals
  if not ALLOWED_ACTIONS[name] then return end; _G[name](player)  -- server table truthy
  if not table.find(APPROVED_PLUGINS, assetId) then return end    -- table.find
  ```

- **validated** — the value passed a validation function luau-shield analysed, a
  [custom sanitizer](../configuration.md#sanitizers), or (when the function
  cannot be resolved) a guard whose name starts with `is`, `validate`, `verify`,
  `check`, `sanitize`, `assert` or `ensure` (see
  [Validation functions](../analysis.md#validation-functions)).

A sink that receives only a **constant** (`loadstring("return 1 + 1")`) or a
**server value** is never a finding: reading a server table with a client key
gives a server value, so `loadstring(SNIPPETS[name])` and
`require(MODULES[name])` are safe even though the client chose the key.

What is **not** a check for luau-shield004:

- **Type annotations and type checks.** `source: string`, `typeof(source) ==
  "string"` and `tonumber(assetId)` do nothing — the exploiter still chooses the
  value. (For the same reason, the number facts that matter to
  [luau-shield001](luau-shield001.md) — bounds, NaN rejection via `x ~= x` — are
  irrelevant here: a bounded, non-NaN asset id is still an attacker's asset id.)
- **Length limits.** `#expression <= 100` still leaves room for
  `game:GetService("Players"):ClearAllChildren()`.
- **Player / admin / ownership checks.** `player.UserId == OWNER_ID`,
  a group-rank check, `x:IsDescendantOf(player.Character)` — these gate *who*
  calls, not *what* runs. The value is still unconstrained.
- **"Sandboxing" at runtime.** `pcall`, `setfenv(chunk, {...})` and similar do
  not make the compiled code safe; luau-shield004 still reports the `loadstring`.

## Limitations

- **Round trips and aliasing are not tracked.** A client value first stored in
  an attribute, a `StringValue` or a `BindableEvent` payload and later compiled,
  or a dispatch table that was itself populated from client input, is not
  followed (see [Limits](../analysis.md#6-limits)). Dispatch through a server
  table is trusted as an allow-list on the assumption that the table holds only
  server-written functions.
- **Unresolved validators are trusted.** A guard calling an unresolved function
  named `isSafeCode(x)` is believed, which can hide a real finding. Disable this
  with `trust-unresolved-validators = false`.
- **Static requires are never flagged.** `require(script.Parent.Module)` and
  other constant or server-value paths are normal and are not reported; only a
  *client-controlled* `require` argument is.
- **The rule does not judge what allow-listed code does.** If a command in your
  dispatch table is itself dangerous (it writes economy data from its own
  arguments, say), that is the concern of the other rules, not luau-shield004.
- **Dynamic code beyond these sinks is not followed.** `getfenv`/`setfenv`
  metatable tricks and functions selected through mechanisms luau-shield does not
  model are out of reach by design.

## Suppressing

Suppress a single finding with a comment and a reason, at the end of the
reported line or on the line directly above it (see
[Suppressing findings](../configuration.md#suppressing-findings)):

```lua
-- luau-shield-ignore: luau-shield004 owner-only console, reviewed and accepted
local chunk = loadstring(source)
```

Suppress the rule for a whole file with a comment at the top of the file:

```lua
-- luau-shield-ignore-file: luau-shield004 trusted build tooling of the private test place
```

Turn the rule off in `luau-shield.toml` (or for one run with
`luau-shield check src --disable luau-shield004`):

```toml
[rules]
luau-shield004 = "off"
```

Turning luau-shield004 off is rarely the right move: untrusted code execution is a
critical, game-ending vulnerability. Prefer an allow-listed dispatch (see the
[fixed example](#fixed-example)), and keep a deliberate console behind an inline
suppression with a reason so the decision is visible in review. See
[How the analysis works](../analysis.md) for the full model of sources, checks
and sinks.
