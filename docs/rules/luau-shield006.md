# luau-shield006: server-invokes-client

The server waits for a client's answer with `RemoteFunction:InvokeClient`
(or assigns `OnClientInvoke` in server code), so a client can make that server
thread wait forever.

| Severity | Default | Applies to |
| --- | --- | --- |
| medium | enabled | server code: Scripts, server modules and every module they reach (replicated or of unknown context); never `*.client.luau` LocalScripts or modules in client folders |

## What it detects

luau-shield006 is about control flow, not about data: it reports the places
where a server thread hands control to a client and waits for it. There are
two sinks:

1. **`InvokeClient` on the server.** Every call of the `InvokeClient` method
   of a RemoteFunction, whatever wraps it:

   ```lua
   local answer = Confirm:InvokeClient(player, question)
   local ok, answer = pcall(Confirm.InvokeClient, Confirm, player, question)
   local ok, answer = pcall(function()
   	return Confirm:InvokeClient(player, question)
   end)
   local ok, answer = xpcall(Confirm.InvokeClient, warn, Confirm, player)
   ```

   The call is **not** reported when it is inside a function passed to one
   of the calls below, because that function runs in its own thread and the
   caller continues right away:

   | Detaching call | Example |
   | --- | --- |
   | `task.spawn`, `task.defer`, `task.delay` | `task.spawn(function() ... end)`, `task.delay(1, askLater, player)` |
   | `coroutine.wrap`, `coroutine.create` | `coroutine.wrap(function() ... end)()` |
   | `spawn`, `delay` (deprecated) | `spawn(function() ... end)` |

   The function can be written inline or be a local function passed by
   name (`task.spawn(collectBid, player)`), as long as that function is not
   also called directly.

2. **`OnClientInvoke` in server code.** An assignment
   `remote.OnClientInvoke = ...` in a `*.server.luau` Script or in a server
   module (under `ServerScriptService` or `ServerStorage`). `OnClientInvoke` is
   the callback a *client* implements: in server code it means either that
   `OnServerInvoke` was meant (and the clients' `InvokeServer` calls on that
   remote never get an answer), or that the server is built around asking
   clients with `InvokeClient`. Replicated modules are not reported for this
   sink, since LocalScripts legitimately require them.

The finding is reported on the line of the `InvokeClient` call (or of the
`remote.InvokeClient` reference passed to `pcall`) and on the line of the
`OnClientInvoke =` assignment. Calls in helpers and required modules are
reported where `InvokeClient` is written, for example inside
`Net.invoke` in `ReplicatedStorage.Shared.Net`, not at every caller.

luau-shield006 never runs on `*.client.luau` LocalScripts or modules in client
folders: `InvokeServer` and `OnClientInvoke` are the normal client-side API
(see [Where code runs](../analysis.md#1-where-code-runs)).

**The answer is client data.** Whatever `InvokeClient` returns was chosen by
the client. It is a [source](../analysis.md#2-sources-of-untrusted-data) for
the other rules, also when the invoke itself runs in a detached thread:

```lua
local bid = AskBid:InvokeClient(player) -- luau-shield006
player.leaderstats.Coins.Value -= bid -- luau-shield001: the client picks the bid
```

## Why it is dangerous

`InvokeClient` yields until the client's `OnClientInvoke` callback returns.
The client controls that callback, so it controls when, or whether, your
server code continues:

- if the callback never returns, the server thread **waits forever** (until
  the player leaves, when `InvokeClient` errors);
- if the callback errors, the error is re-thrown on the server, and the code
  after the call is skipped unless it is wrapped in `pcall`;
- the returned values are whatever the client wants them to be.

`pcall` handles the error cases, not the first one: a call that never
returns never fails. An exploiter only has to replace the callback in their
executor:

```lua
-- Run by the exploiter in their executor, not by your game.
local ConfirmTrade = game:GetService("ReplicatedStorage").Remotes.ConfirmTrade
ConfirmTrade.OnClientInvoke = function()
	while true do
		task.wait(60) -- never answer
	end
end
```

What this does depends on where the invoke is:

- **In a loop or a shared flow**, one silent client blocks everybody: a map
  vote that asks players one after the other never finishes, and the round
  system of the whole server freezes with it.
- **In a relay** (a `RemoteFunction` handler that asks another player and
  returns the answer), the player waiting on the other end is stuck too: the
  inviter's "Waiting..." screen never goes away.
- **In a handler the exploiter can trigger at will**, every request parks one
  more server thread with its stack and upvalues. Threads pile up until the
  exploiter leaves, which is a slow memory leak for the whole server.

## Vulnerable example

```lua
-- ServerScriptService/Trading.server.luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Trading = require(ServerScriptService.Trading)

local Remotes = ReplicatedStorage.Remotes
local RequestTrade = Remotes.RequestTrade :: RemoteEvent
local ConfirmTrade = Remotes.ConfirmTrade :: RemoteFunction

RequestTrade.OnServerEvent:Connect(function(player: Player, targetUserId: unknown)
	if typeof(targetUserId) ~= "number" then
		return
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player then
		return
	end
	-- pcall catches errors, not a client that never answers
	local ok, accepted = pcall(ConfirmTrade.InvokeClient, ConfirmTrade, target, player.Name) -- luau-shield006
	if ok and accepted == true then
		Trading.start(player, target)
	end
end)
```

The trade partner decides when this handler continues. A partner that never
answers leaves the handler waiting forever, and an exploiter with a second
account can fire `RequestTrade` at its silent main account again and again:
every request adds one more waiting thread.

## Fixed example

The robust fix is to never wait on a client: ask with one `RemoteEvent`,
accept the answer on another, and let pending requests expire on the server.

```lua
-- ServerScriptService/Trading.server.luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Trading = require(ServerScriptService.Trading)

local Remotes = ReplicatedStorage.Remotes
local RequestTrade = Remotes.RequestTrade :: RemoteEvent
local TradeRequest = Remotes.TradeRequest :: RemoteEvent
local TradeAnswer = Remotes.TradeAnswer :: RemoteEvent

local REQUEST_TIMEOUT = 15
local pending: { [Player]: { from: Player, expires: number } } = {}

RequestTrade.OnServerEvent:Connect(function(player: Player, targetUserId: unknown)
	if typeof(targetUserId) ~= "number" then
		return
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player then
		return
	end
	local existing = pending[target]
	if existing and os.clock() < existing.expires then
		return -- the target is still answering another request
	end
	pending[target] = { from = player, expires = os.clock() + REQUEST_TIMEOUT }
	TradeRequest:FireClient(target, player.Name)
end)

TradeAnswer.OnServerEvent:Connect(function(player: Player, accepted: unknown)
	local request = pending[player]
	if not request or typeof(accepted) ~= "boolean" then
		return
	end
	pending[player] = nil
	if accepted and os.clock() <= request.expires and request.from.Parent == Players then
		Trading.start(request.from, player)
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	pending[player] = nil
end)
```

Nothing waits on a client any more: a partner that never answers only leaves
an entry that expires after `REQUEST_TIMEOUT` seconds.

If you must keep a `RemoteFunction`, run the invoke in a detached thread and
stop waiting after a timeout. A small helper keeps every caller honest:

```lua
-- ReplicatedStorage/Shared/Net.luau
local Net = {}

local inFlight: { [Player]: boolean } = {}

function Net.invokeClient(remote: RemoteFunction, player: Player, timeout: number, ...: any): (boolean, any)
	if inFlight[player] then
		return false, "busy" -- at most one unanswered question per player
	end
	inFlight[player] = true
	local caller = coroutine.running()
	local args = table.pack(...)
	local finished = false

	local function finish(ok: boolean, result: any)
		if finished then
			return
		end
		finished = true
		task.spawn(caller, ok, result)
	end

	-- the invoke runs in its own thread; the caller is resumed by the answer
	-- or by the timeout, whichever comes first
	task.defer(function()
		finish(pcall(remote.InvokeClient, remote, player, table.unpack(args, 1, args.n)))
		inFlight[player] = nil
	end)
	task.delay(timeout, finish, false, "timed out")
	return coroutine.yield()
end

return Net
```

```lua
local ok, accepted = Net.invokeClient(ConfirmTrade, target, 15, player.Name)
if ok and accepted == true then
	Trading.start(player, target)
end
```

`InvokeClient` is now inside a function passed to `task.defer`, so
luau-shield006 is satisfied, and the caller never waits more than the
timeout. The answer is still client data: here only a literal `true` is
accepted.

## What counts as a check

No value check silences luau-shield006: the rule is about *waiting*, not about
what comes back. What satisfies it is where the call runs:

```lua
-- detached: the caller continues immediately
task.spawn(function()
	local ok, language = pcall(GetLanguage.InvokeClient, GetLanguage, player)
	if ok and typeof(language) == "string" and SUPPORTED_LANGUAGES[language] then
		player:SetAttribute("Language", language)
	end
end)

-- a local function passed by name is detached too
task.spawn(collectBid, player)

-- best of all: no RemoteFunction, a FireClient + OnServerEvent round trip
TradeRequest:FireClient(target, player.Name)
```

What is **not** enough:

- **`pcall` / `xpcall`.** They catch errors; a client that never answers
  raises none.
- **A timeout in another thread.** `task.delay(5, warnIfNoAnswer)` next to a
  blocking `InvokeClient` runs on time, but the thread that called
  `InvokeClient` is still waiting. Only the code *inside* the function passed
  to `task.delay` is detached.
- **Checking the answer.** `typeof(answer) == "boolean"` makes the answer
  safe for the other rules; it does not make the wait any shorter.

Because the answer is client data, check it as you would check a remote
parameter (see [Checks](../analysis.md#4-checks-sanitizers)). Type
annotations are not checks: `local bid: number = AskBid:InvokeClient(player)`
can still be a string, a table or NaN. A number written to stats needs a
type check, a lower and an upper bound and NaN rejected for
[luau-shield001](luau-shield001.md) (`bid ~= bid` rejects NaN; `bid <= 0 or
bid > max` alone does not); a value for an Instance property needs the facts
listed by [luau-shield002](luau-shield002.md).

## Limitations

- **Detached is not the same as bounded.** The rule only looks at where
  `InvokeClient` runs. A caller that detaches the invoke and then polls for
  the answer without a deadline (`repeat task.wait() until answered`) waits
  forever just the same, and is not reported. Neither is a vote that asks
  players one after another inside a single `task.spawn`: the round loop
  keeps going, but one silent player still stalls the vote. Always pair a
  detached invoke with a timeout.
- **Detached threads still leak.** An unanswered invoke keeps its detached
  thread alive until the player leaves. If a remote handler can start
  invokes at will, allow at most one unanswered invoke per player (as
  `Net.invokeClient` above does); luau-shield006 does not check this.
- **Detaching is decided where `InvokeClient` is written.** A local helper
  that calls `InvokeClient` and is only called from inside a spawned closure
  (`task.spawn(function() collectBid(player) end)`) is still reported,
  because the helper itself is not the function passed to `task.spawn`.
  Pass the helper by name (`task.spawn(collectBid, player)`) or suppress the
  finding.
- **Other thread libraries are not recognised.** Invokes inside `Promise.new`
  executors, custom thread pools or signal libraries are reported even when
  they run in their own thread. Suppress them with a reason.
- **Dynamic calls are missed.** `remote["InvokeClient"](remote, player)` and
  method names built at runtime are not recognised.
- **Answers that come back through a thread are not followed.** Values passed
  from the invoking thread back to the caller with `task.spawn(caller, ...)`
  / `coroutine.yield()`, a `BindableEvent` or an attribute lose their
  "client data" mark (see [Limits](../analysis.md#6-limits)), so the other
  rules do not check them. Validate them anyway.
- **`OnClientInvoke` in replicated modules is not reported**, even when the
  module also runs on the server.

## Suppressing

Suppress a single finding with a comment and a reason, at the end of the
reported line or on the line directly above it (see
[Suppressing findings](../configuration.md#suppressing-findings)):

```lua
local answer = DebugProbe:InvokeClient(player) -- luau-shield-ignore: luau-shield006 Studio-only test harness, disabled in live servers

-- luau-shield-ignore: luau-shield006 runs inside Promise.new, which already uses its own thread
local result = Confirm:InvokeClient(player)
```

Suppress the rule for a whole file with a comment at the top of the file:

```lua
-- luau-shield-ignore-file: luau-shield006 legacy minigame, replaced next season
```

Turn the rule off in `luau-shield.toml` (or for one run with
`luau-shield check src --disable luau-shield006`):

```toml
[rules]
luau-shield006 = "off"
```

The same table can also raise its severity instead, for teams that never
want `InvokeClient` on the server (see [Rules](../configuration.md#rules)):

```toml
[rules]
luau-shield006 = "high"
```
