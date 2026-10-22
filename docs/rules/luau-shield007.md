# luau-shield007: remote-without-rate-limit

A remote handler does expensive work (`*Async` calls, `Instance.new`,
`:Clone()`) every time the client fires it, with no rate limit, so one
client can flood the server.

| Severity | Default | Applies to |
| --- | --- | --- |
| low | enabled | server code: Scripts, server modules and every module they reach (replicated or of unknown context); never `*.client.luau` LocalScripts or modules in client folders |

## What it detects

luau-shield007 is about *how often* a handler can run, not about the values
it receives. It looks at every remote handler of the server:

- `remote.OnServerEvent:Connect(handler)` (also `:Once` and
  `:ConnectParallel`), for `RemoteEvent` and `UnreliableRemoteEvent`;
- `remote.OnServerInvoke = handler`.

The handler can be an inline function, a local function connected by name
(`Remote.OnServerEvent:Connect(onBuy)`), a module function, or a function
stored in a table and connected in a loop (see
[Sources of untrusted data](../analysis.md#2-sources-of-untrusted-data)).

A handler is reported when it does **expensive work**:

| Expensive work | Examples |
| --- | --- |
| a method call whose name ends in `Async` | `store:SetAsync(...)`, `store:UpdateAsync(...)`, `store:GetAsync(...)`, `HttpService:PostAsync(...)`, `HttpService:RequestAsync(...)`, `MessagingService:PublishAsync(...)`, `TeleportService:TeleportAsync(...)`, `TextService:FilterStringAsync(...)`, `BadgeService:UserHasBadgeAsync(...)`, `GroupService:GetGroupsAsync(...)` |
| `Instance.new(...)` | `Instance.new("Part")`, `Instance.new("TeleportOptions")` |
| a `:Clone()` method call | `ServerStorage.Tools.Sword:Clone()`, `template:Clone()` |

and shows **no rate-limit evidence** (see
[What counts as a check](#what-counts-as-a-check)).

The work counts wherever it runs on behalf of the request:

- directly in the handler, including inside closures created there
  (`pcall(function() ... end)`, `task.spawn(function() ... end)`): a
  detached thread still runs once per request;
- through the `pcall` idiom that passes the method itself:
  `pcall(store.SetAsync, store, key, value)` is a `SetAsync` call;
- in local functions of the same file and functions of required modules
  that the handler calls, followed like taint is followed
  ([Propagation](../analysis.md#3-propagation)).

There is **one finding per handler**, reported on the line that contains
`OnServerEvent` or `OnServerInvoke`: the `:Connect(` line of an inline
handler, the `Remote.OnServerEvent:Connect(onBuy)` line of a handler
connected by name, the line inside the loop for handlers connected from a
table, and the `remote.OnServerInvoke =` line. The message lists the
expensive calls it found, for example:

```text
the `SaveSettings.OnServerEvent` handler calls `settingsStore:SetAsync()` on every request, with no rate limit
```

Work outside remote handlers is never reported: loading data in
`Players.PlayerAdded`, saving in `Players.PlayerRemoving` or in an autosave
loop is the normal place for DataStore calls.

luau-shield007 never runs on `*.client.luau` LocalScripts or modules in
client folders (see [Where code runs](../analysis.md#1-where-code-runs)).

## Why it is dangerous

A remote handler runs every time a client fires the remote, and an exploiter
fires it as often as they like, not when your UI allows it:

```lua
-- Run by the exploiter in their executor, not by your game.
local SaveSettings = game:GetService("ReplicatedStorage").Remotes.SaveSettings
while true do
	for _ = 1, 100 do
		SaveSettings:FireServer(true, true)
	end
	task.wait()
end
```

The expensive APIs share budgets and resources with everybody in the server
(or in the whole experience):

- **DataStores** have per-server request budgets that grow with the number of
  players. One player spending them on `SetAsync` means the autosave and the
  `PlayerRemoving` save of everyone else start failing or waiting in the
  throttle queue: players lose progress.
- **HttpService** allows 500 requests per minute per server. Spamming a
  "report a bug" remote that posts to a webhook uses the whole budget (and
  gets the webhook banned by the receiving service).
- **MessagingService** budgets are shared by every server of the experience:
  one exploiter spamming a global shout silences cross-server messages
  everywhere.
- **TeleportService, TextService, BadgeService, GroupService,
  MarketplaceService** calls are web requests with their own throttles; when
  they are used up, legitimate teleports, chat filtering or badge checks fail.
- **`Instance.new` and `:Clone()`** cost memory and replication bandwidth.
  Thousands of parts, effects or tools per second lag every client and
  eventually crash the server.
- Every `*Async` call **yields**: each request parks one more thread on the
  server until the call returns.

The severity is low because the damage is to availability, not to the
integrity of the game: no data is forged. It is still an easy way to ruin a
server for everyone.

## Vulnerable example

```lua
-- ServerScriptService/Settings.server.luau
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local settingsStore = DataStoreService:GetDataStore("Settings")
local SaveSettings = ReplicatedStorage.Remotes.SaveSettings :: RemoteEvent

SaveSettings.OnServerEvent:Connect(function(player: Player, music: unknown, effects: unknown) -- luau-shield007
	if typeof(music) ~= "boolean" or typeof(effects) ~= "boolean" then
		return
	end
	local ok, err = pcall(function()
		settingsStore:SetAsync(tostring(player.UserId), { music = music, effects = effects })
	end)
	if not ok then
		warn(`could not save the settings of {player.UserId}: {err}`)
	end
end)
```

The arguments are checked, so [luau-shield001](luau-shield001.md) is
satisfied, but nothing limits how often the handler writes to the DataStore.

## Fixed example

Keep the time of the last accepted request per player and ignore requests
that come too soon:

```lua
-- ServerScriptService/Settings.server.luau
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local settingsStore = DataStoreService:GetDataStore("Settings")
local SaveSettings = ReplicatedStorage.Remotes.SaveSettings :: RemoteEvent

local SAVE_COOLDOWN = 10 -- seconds
local lastSave: { [Player]: number } = {}

SaveSettings.OnServerEvent:Connect(function(player: Player, music: unknown, effects: unknown)
	local now = os.clock()
	if now - (lastSave[player] or -math.huge) < SAVE_COOLDOWN then
		return -- too soon: ignore the request
	end
	if typeof(music) ~= "boolean" or typeof(effects) ~= "boolean" then
		return
	end
	lastSave[player] = now
	local ok, err = pcall(function()
		settingsStore:SetAsync(tostring(player.UserId), { music = music, effects = effects })
	end)
	if not ok then
		warn(`could not save the settings of {player.UserId}: {err}`)
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastSave[player] = nil
end)
```

Often the better fix is to make the handler cheap. Keep the settings in
memory and write them once, when the player leaves (and in your autosave):
no change is lost to the cooldown, and there is nothing to report.

```lua
type Settings = { music: boolean, effects: boolean }
local settings: { [Player]: Settings } = {}

-- cheap: only updates memory, however often it is fired
SaveSettings.OnServerEvent:Connect(function(player: Player, music: unknown, effects: unknown)
	if typeof(music) ~= "boolean" or typeof(effects) ~= "boolean" then
		return
	end
	settings[player] = { music = music, effects = effects }
end)

-- one write per session, outside any remote handler
Players.PlayerRemoving:Connect(function(player: Player)
	local current = settings[player]
	settings[player] = nil
	if current then
		pcall(function()
			settingsStore:SetAsync(tostring(player.UserId), current)
		end)
	end
end)
```

The same goes for web lookups: check a badge or a game pass once in
`PlayerAdded`, cache the answer per player, and let the remote handler read
the cache.

## What counts as a check

Rate-limit evidence anywhere in the handler, or in the local and module
functions it calls, silences the finding. Any of these is evidence:

1. **A clock call**: `os.clock()`, `tick()`, `time()`, `os.time()`,
   `DateTime.now()`, `workspace:GetServerTimeNow()`. This is what a
   per-player cooldown needs:

   ```lua
   local lastConfetti: { [Player]: number } = {}

   Remotes.Confetti.OnServerEvent:Connect(function(player: Player)
   	local now = os.clock()
   	if now - (lastConfetti[player] or -math.huge) < 2 then
   		return
   	end
   	lastConfetti[player] = now
   	template:Clone().Parent = workspace
   end)
   ```

   The clock can also be in a helper the handler calls, for example a shared
   module:

   ```lua
   local Net = require(ReplicatedStorage.Shared.Net) -- Net.canFire uses os.clock()

   if not Net.canFire(player, "Firework", 2) then
   	return
   end
   ```

2. **A rate-limiter call**: a call to a function or method whose name
   contains (ignoring case) `ratelimit`, `rate_limit`, `throttle`,
   `cooldown`, `debounce` or `limiter`. The name is matched on the call as
   written, module or receiver included, so packages that are not part of
   the checked tree are recognised too:

   ```lua
   local RateLimiter = require(ReplicatedStorage.Packages.RateLimiter)
   local limiter = RateLimiter.new(1, 5)

   if not limiter:CheckRate(player) then -- matched through `limiter`
   	return
   end
   ```

   `RateLimiter.check(player)`, `Cooldowns.consume(player, "Dash")` and
   `self:IsOnCooldown(player)` are recognised the same way.

3. **A wrapped handler**: the function passed to `Connect` is the result of a
   call with such a name:

   ```lua
   Remotes.BuyItem.OnServerEvent:Connect(rateLimited(onBuyItem))

   for name, handler in handlers do
   	PetRemotes[name].OnServerEvent:Connect(throttle(handler, 1))
   end
   ```

4. **A per-player lock**: the handler checks `T[player]` (or
   `T[player.UserId]`) in an early-return guard *and* assigns the same entry:

   ```lua
   local busy: { [Player]: boolean } = {}

   Remotes.Play.OnServerEvent:Connect(function(player: Player)
   	if busy[player] then
   		return
   	end
   	busy[player] = true
   	pcall(TeleportService.TeleportAsync, TeleportService, ARENA_PLACE_ID, { player })
   	busy[player] = nil
   end)
   ```

   A lock that is set and never cleared allows one run per session, which
   is the right shape for "claim once" rewards.

What is **not** enough:

- **A single flag for everyone.** `local debounce = false` around the work
  only stops two requests from overlapping. The exploiter fires again as
  soon as the previous call returns, and while they do, real players are
  turned away. Key the state by player.
- **A guard that is never set.** `if crafting[player] then return end`
  does nothing if no code path of the handler assigns `crafting[player]`.
- **A read that is not a guard.** `if summoned[player] then
  summoned[player]:Destroy() end` followed by `summoned[player] = pet`
  replaces the previous pet but never stops the next request.
- **`pcall` or `task.spawn` around the work.** They handle errors and
  yielding; every request still does the work, and detaching removes even
  the natural back-pressure of waiting for the previous call.
- **A cooldown on another remote.** Evidence only counts for the handler it
  is in (and the functions that handler calls).
- **A cooldown on the client.** Disabling the button in a LocalScript does
  not stop an exploiter from calling `FireServer` directly.
- **Checking the arguments.** Type checks, bounds and NaN rejection (as
  required by [luau-shield001](luau-shield001.md)) decide *what* the client
  may send, not *how often*. Type annotations are not checks either:
  `function(player, amount: number)` limits nothing at runtime.

## Limitations

The rule looks for evidence, it does not prove that the limit works:

- **Any clock call counts.** `local start = os.clock()` used only to log
  how long a save took, a cooldown checked *after* the expensive work, a
  limit of `0.01` seconds, or a single server-wide timestamp all silence the
  finding. Make sure the clock is used to return early, per player, before
  the work.
- **Names count, whatever the call does.** The rate-limiter words are
  matched on the whole call, so `Remotes.CooldownStarted:FireClient(player,
  5)`, which only tells the client about a cooldown, counts as evidence.
- **A lock limits concurrency, not frequency.** A busy flag released when
  the work finishes still lets a client run it back to back. That is fine
  for slow, one-at-a-time work such as a teleport; for frequent DataStore
  writes prefer a time-based cooldown. The lock is recognised by its shape:
  a lock keyed by a timestamp the *client* sends looks the same as a real
  one.
- **Only the listed work is expensive.** Calls that are expensive but do
  not end in `Async` (`player:LoadCharacter()`,
  `Humanoid:ApplyDescription()`, `BadgeService:AwardBadge()`,
  `MarketplaceService:GetProductInfo()`, `InsertService:LoadAsset()`),
  `Instance.fromExisting`, and loops or allocations sized by client values
  (`table.create(count)`, `string.rep(s, count)`) are not reported. Method
  names built at runtime (`store[method](store, key)`) are not recognised
  either.
- **Only `OnServerEvent` and `OnServerInvoke` handlers are checked.** Knit
  `Client` methods, `player.Chatted` callbacks, [custom
  sources](../configuration.md#sources) and handlers reached through
  `BindableEvent`s are not checked by this rule (the other rules still
  follow their values).
- **Calls are followed to a limited depth** (6 by default), and calls into
  unresolved modules are not followed: expensive work hidden there is
  missed, and rate limiting implemented there is only seen when the call's
  name contains one of the words above.
- **Handlers that can only run a few times are still reported.** A
  `:Once` handler, a handler that disconnects itself, or work bounded by
  game state (a tool that is cloned only after its price was paid, an
  `*Async` call whose result Roblox caches, such as
  `UserOwnsGamePassAsync`) is reported like any other. Add a cheap cooldown
  or suppress the finding with a reason.

## Suppressing

Suppress a single finding with a comment and a reason, at the end of the
reported line (the `OnServerEvent` / `OnServerInvoke` line) or on the line
directly above it (see
[Suppressing findings](../configuration.md#suppressing-findings)):

```lua
-- luau-shield-ignore: luau-shield007 called at most once per round by the game loop
Remotes.ReadyUp.OnServerEvent:Once(function(player)
	ServerStorage.Effects.ReadyBeam:Clone().Parent = player.Character
end)

Remotes.Purchase.OnServerEvent:Connect(onPurchase) -- luau-shield-ignore: luau-shield007 every call costs coins
```

Suppress the rule for a whole file with a comment at the top of the file:

```lua
-- luau-shield-ignore-file: luau-shield007 admin remotes, only callable by group admins
```

Turn the rule off in `luau-shield.toml` (or for one run with
`luau-shield check src --disable luau-shield007`):

```toml
[rules]
luau-shield007 = "off"
```

Because the default `--fail-on low` fails on any finding, teams that want
luau-shield007 reported but not blocking can run with
`--fail-on medium`, or raise the rule's severity instead when they want it
to count more (see [Rules](../configuration.md#rules)):

```toml
[rules]
luau-shield007 = "medium"
```
