# luau-shield001: untrusted-economy-write

A value controlled by the client is written to currency, stats,
`leaderstats`, persistent player data, or a DataStore / MemoryStore without
being checked enough.

| Severity | Default | Applies to |
| --- | --- | --- |
| high | enabled | server code: Scripts, server modules and every module they reach (replicated or of unknown context); never `*.client.luau` LocalScripts or modules in client folders |

## What it detects

luau-shield001 follows values that come from the client (the parameters of
`OnServerEvent` / `OnServerInvoke` handlers after `player`, values returned by
`InvokeClient`, `player.Chatted` messages, Knit `Client` methods: see
[Sources of untrusted data](../analysis.md#2-sources-of-untrusted-data))
through variables, tables, local functions and required modules
([Propagation](../analysis.md#3-propagation)). It reports a finding when such a
value reaches one of the sinks below without the checks listed in
[What counts as a check](#what-counts-as-a-check).

**Stat words.** Several sinks are recognised by name. An identifier matches
when one of its words (split on camelCase and snake_case, compared without
case) is one of: `coins` `coin` `cash` `money` `gold` `gems` `gem` `diamonds`
`diamond` `points` `xp` `exp` `experience` `level` `levels` `kills` `wins`
`score` `credits` `tokens` `bucks` `balance` `currency` `robux` `rebirths`
`crystals` `stats` `leaderstats`. For example `Coins`, `BankBalance`,
`total_xp` and `DonatedGems` match; `Bank` and `Coinage` do not.

The sinks are:

1. **Stat objects.** Assignment or compound assignment to `X.Value` when the
   path of `X` contains `leaderstats` or a stat word:

   ```lua
   player.leaderstats.Coins.Value += amount
   stats.Cash.Value = stats.Cash.Value + reward
   ```

   This includes local aliases of such objects, also when they are obtained
   with `FindFirstChild` or `WaitForChild`:

   ```lua
   local coins = player.leaderstats.Coins
   local gems = player:WaitForChild("leaderstats"):WaitForChild("Gems")
   local cash = leaderstats:FindFirstChild("Cash")
   coins.Value += amount
   ```

2. **Data tables.** Assignment or compound assignment to a table field whose
   key is a stat word, unless the table is a table literal created in the same
   function:

   ```lua
   data.Coins = amount
   profile.Data.Gems += amount
   PlayerData[player].Cash = amount
   ```

   A *persistent-data container* is a table whose access path contains one
   of the words `data`, `profile`, `save`, `inventory`, `stats` or `session`
   (also with an `s`: `sessions`, `profiles`); local aliases keep the path
   (`local inventory = profile.Data.Inventory`). Any write with a
   **client-controlled key** into such a container, or into a table whose
   path contains a stat word, is a sink, whatever the value:

   ```lua
   data.Inventory[itemName] = true
   inventory[itemId] = (inventory[itemId] or 0) + count
   ```

   A client value written to any other field of a persistent-data container
   (`profile.Data.Title = title`) is checked the same way as a stat field.

3. **Stat attributes.** `instance:SetAttribute(name, value)` when `name` is a
   stat word (`"Coins"`, `"Level"`, ...). Other attribute names are covered by
   [luau-shield002](luau-shield002.md).

4. **DataStores.** `SetAsync`, `UpdateAsync`, `IncrementAsync` and
   `RemoveAsync` with a client-controlled **key** or **value**. For
   `UpdateAsync` the value is whatever the transform function returns. The
   receiver is a store obtained from `DataStoreService:GetDataStore`,
   `GetOrderedDataStore` or `GetGlobalDataStore`, or any variable whose name
   contains `Store` (or `store`).

5. **MemoryStores.** `SetAsync`, `UpdateAsync`, `AddAsync` and `RemoveAsync`
   on objects obtained from `MemoryStoreService:GetSortedMap`, `GetQueue` or
   `GetHashMap`.

For DataStores and MemoryStores the first argument is the key (except for a
queue's `AddAsync`, whose first argument is the value) and every other
argument is checked as a value: the saved value, but also a sort key or a
queue priority. A table is checked through its fields, so a table literal
built from client values and then saved is reported on the save:

```lua
local record = { Score = 0, SavedAt = os.time() }
record.Score = result.score -- not reported: a fresh table is just a message
arcadeStore:SetAsync(`arcade_{player.UserId}`, record) -- reported here
```

The finding is reported on the line of the assignment or of the method call.
When the write happens inside a helper (for example `Economy.addCoins` in a
required module), the finding is on the write inside the helper, and the
client value is the one passed by the remote handler that called it.

## Why it is dangerous

Remotes are the only way a client can talk to the server, and an exploiter
controls every argument of every call. With an executor and a remote spy,
they see the remotes your LocalScripts fire and can fire them again with any
arguments:

```lua
-- Run by the exploiter in their executor, not by your game.
local remotes = game:GetService("ReplicatedStorage").Remotes
remotes.CollectCoins:FireServer(1e9) -- "I picked up a billion coins"
remotes.GiftCoins:FireServer("Victim", -50000) -- a negative gift steals coins
remotes.Withdraw:FireServer(0 / 0) -- NaN slips through "amount <= 0" checks
```

If the server writes these values to stats or saved data, the damage is
persistent: the exploiter tops leaderboards, buys everything, floods a trading
economy with currency or items, and the corrupted values are saved and loaded
back on every join. NaN is especially nasty: once a balance is NaN, every
`price > balance` check is false, so everything becomes free. A
client-controlled DataStore key lets an exploiter overwrite or delete other
players' saves. Cleaning this up means rolling back data for many players.

## Vulnerable example

```lua
-- ServerScriptService/Bank.server.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Profiles = require(ServerScriptService.Profiles)

local Withdraw = ReplicatedStorage.Remotes.Withdraw :: RemoteEvent

Withdraw.OnServerEvent:Connect(function(player: Player, amount: number)
	local profile = Profiles.get(player)
	if not profile then
		return
	end
	-- `amount: number` is not a check, and NaN passes both comparisons.
	if amount <= 0 or amount > profile.Data.BankBalance then
		return
	end
	profile.Data.BankBalance -= amount -- luau-shield001
	profile.Data.Cash += amount -- luau-shield001
end)
```

The guard looks complete, but it only rejects values for which a comparison
is *true*. Every comparison with NaN is false, so `Withdraw:FireServer(0 / 0)`
passes it and turns both balances into NaN.

## Fixed example

```lua
-- ServerScriptService/Bank.server.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Profiles = require(ServerScriptService.Profiles)

local Withdraw = ReplicatedStorage.Remotes.Withdraw :: RemoteEvent

Withdraw.OnServerEvent:Connect(function(player: Player, amount: unknown)
	local profile = Profiles.get(player)
	if not profile then
		return
	end
	if typeof(amount) ~= "number" or amount ~= amount then
		return -- not a number, or NaN
	end
	if amount < 1 or amount > profile.Data.BankBalance then
		return
	end
	profile.Data.BankBalance -= amount
	profile.Data.Cash += amount
end)
```

The amount now has every fact luau-shield001 needs for a number: its type, a lower
bound, an upper bound (the balance, a server value) and NaN rejected.

The most robust fix is often not to accept an amount at all: let the client
say *what* it wants (an item id, a quest id) and compute the amount on the
server:

```lua
local PRICES = { Sword = 100, Shield = 250 }

BuyItem.OnServerEvent:Connect(function(player: Player, itemId: unknown)
	local profile = Profiles.get(player)
	if not profile or typeof(itemId) ~= "string" or not PRICES[itemId] then
		return -- from here on, itemId is allow-listed
	end
	local price = PRICES[itemId] -- a server value, whatever the key was
	if profile.Data.Cash < price then
		return
	end
	profile.Data.Cash -= price
	profile.Data.Inventory[itemId] = true
end)
```

## What counts as a check

A value accumulates *facts* as it passes checks (see
[Checks](../analysis.md#4-checks-sanitizers)). A check only protects the code
that runs after it succeeds: an early `return`, `error(...)`, `assert(...)`,
or the body of an `if` whose condition holds. For luau-shield001 a client value is
safe when it is:

- **allow-listed**: `itemId == "Sword"`, `PRICES[itemId]` truthy (a server
  table), `table.find(ALLOWED, itemId)`, `folder:FindFirstChild(itemId)`
  non-nil;
- **validated**: it passed a validation function that luau-shield analysed, a
  [custom sanitizer](../configuration.md#sanitizers), or an unresolved guard
  whose name starts with `is`, `validate`, `verify`, `check`, `sanitize`,
  `assert` or `ensure` (see
  [Validation functions](../analysis.md#validation-functions));
- a **boolean** that passed a type check (`typeof(x) == "boolean"`);
- a **number** with all four of: type, lower bound, upper bound, NaN rejected;
- a **string** with a type check and a length limit (`#s <= 20`), or an
  anchored pattern (`s:match("^%w+$")`).

Client-controlled **keys** (DataStore keys, `data.Inventory[itemName]`) are
held to a stricter standard, because a key decides *which* entry is written:
it must be allow-listed, validated, matched by an anchored pattern, or a
number with all four facts. A type check plus a length limit is enough for a
string *value* such as a pet nickname, but not for a key: `#itemName <= 20`
still lets the client name any item.

```lua
-- the key is built on the server; the client only picks one of its slots
if not table.find(SLOTS, slot) then
	return
end
slotStore:RemoveAsync(`slot_{player.UserId}_{slot}`)
```

Number checks that are enough:

```lua
-- explicit guard: type, NaN, lower and upper bound
if typeof(amount) ~= "number" or amount ~= amount or amount < 1 or amount > MAX then
	return
end

-- "must be true" form: false for NaN, so NaN never enters the block
if typeof(amount) == "number" and amount >= 1 and amount <= MAX then
	coins.Value += amount
end

-- a validation function in the same file or in a required module
local function isValidAmount(n: unknown): boolean
	return typeof(n) == "number" and n == n and n >= 1 and n <= MAX
end
if not isValidAmount(amount) then
	return
end

-- the t library: numberConstrained gives type, bounds and NaN rejected
local check = t.tuple(t.string, t.numberConstrained(1, 99))
if not check(itemId, quantity) then
	return
end
```

What is **not** a check:

- **Type annotations.** `function(player, amount: number)` receives whatever
  the client sends: Luau types are erased at runtime.
- **A type check alone.** `typeof(amount) == "number"` lets `1e9`, `-1e9`
  and NaN through, and `tonumber(x)` is no better. `t.number` also rejects
  NaN, but any size still passes.
- **One bound.** `amount > 0` alone, `amount <= coins.Value` alone, or
  `math.max(0, x)` leave the other side open: a negative gift or a huge
  reward still works.
- **Bounds written as "reject if true" without a NaN test.**
  `if amount <= 0 or amount > 100 then return end` does not reject NaN,
  because both comparisons are false for NaN. Add `amount ~= amount` to the
  guard, or write the bounds in the "must be true" form.
- **`math.clamp`, `math.min`, `math.max`.** They give bounds, but NaN can
  come out of them: `math.clamp(0 / 0, 1, 100)` is NaN.
- **Unanchored searches.** `string.find(key, tostring(player.UserId))` or
  `key:match("%d+")` do not constrain the rest of the string.

## Limitations

- **Names decide what counts as economy.** Stat objects and data fields are
  recognised by the stat words above, and persistent containers by
  `data`/`profile`/`save`/`inventory`/`stats`/`session` in their access path.
  A currency named `Doubloons` that does not live under `leaderstats`, or a
  saved table reached through unrelated names (`local bag = store[player]`
  then `bag[itemName] = true`), is not reported. Put such writes behind a
  helper and declare it with a [`[[sinks]]`](../configuration.md#sinks) entry
  (`function = "Economy.addDoubloons"`, `rule = "luau-shield001"`). In the other
  direction, an unrelated field that happens to use a stat word (`map.Level`)
  is reported when it receives an unchecked client value.
- **Wrappers with other method names.** `GetDataStore` stores, variables whose
  name contains `Store` and `profile.Data` writes are covered. Libraries that
  wrap DataStores behind other method names (for example DataStore2's
  `:Set()` and `:Increment()`) are not sinks by default; declare them with
  [`[[sinks]]`](../configuration.md#sinks).
- **Bounds are not judged.** A bound that is present but wrong
  (`amount <= 1e15`) counts as a check, and so does a check against the wrong
  maximum.
- **Valid is not earned.** luau-shield001 checks that a value is constrained, not that
  the player deserved it: a reward validated to `[1, 100]` can still be
  claimed for nothing, or claimed again and again. Prefer computing amounts on
  the server from server state.
- **Whole numbers are not required.** Fractional amounts pass the rule; add
  `amount % 1 == 0` when your economy needs integers.
- **Round trips are not tracked.** A client value first stored in a
  `StringValue`, an attribute or a `BindableEvent` payload and later copied to
  stats is not followed (see [Limits](../analysis.md#6-limits)).
- **Fresh tables.** Writes to a table literal created in the same function
  (`local preview = {}; preview.Coins = offer.coins`) are not reported, since
  such a table is usually a reply or a message. If that table is then saved,
  the DataStore call is what gets checked.
- **Keys checked by a pattern.** An anchored pattern is accepted for keys.
  That is right for a namespaced DataStore key (`clan_<name>` with
  `^%w+$`: no other key can be reached), but `itemName:match("^%w+$")`
  before `data.Inventory[itemName] = true` still lets the client name any
  item and is not reported. Allow-list item ids against your catalog.
- **NaN rejections that are not recognised.** Only `x == x`, `x ~= x` and
  comparisons that must be true reject NaN for luau-shield. Some code is
  NaN-safe in other ways and is still reported:
  `if x % 1 ~= 0 then return end` (`NaN % 1` is NaN), `math.max(1, x)`
  (Luau keeps the first argument when a later one is NaN, so the order
  matters), or `t.number(x)` followed by bounds written as
  `if x < 1 or x > 100 then return end` (the real `t.number` rejects NaN,
  but luau-shield gives it only the type fact). Add an explicit `x ~= x`
  test or use `t.numberConstrained`.
- **Checks on a different copy.** `local amount = req.amount` taken *before*
  `req.amount` is checked does not receive the facts of that check. Check
  the variable you write, or copy after checking.
- **Unknown functions.** The result of a call to an unresolved function is
  considered client-controlled when one of its arguments is, which can cause
  false positives; declare the function as a
  [sanitizer](../configuration.md#sanitizers) if it returns a checked value.

## Suppressing

Suppress a single finding with a comment and a reason, at the end of the
reported line or on the line directly above it (see
[Suppressing findings](../configuration.md#suppressing-findings)):

```lua
coins.Value += amount -- luau-shield-ignore: luau-shield001 amount is signed by the server and verified by RewardTokens

-- luau-shield-ignore: luau-shield001 admin-only panel, gated by the group rank check above
profile.Data.Gems = requested
```

Suppress the rule for a whole file with a comment at the top of the file:

```lua
-- luau-shield-ignore-file: luau-shield001 economy tools of the private test place
```

Turn the rule off in `luau-shield.toml` (or for one run with
`luau-shield check src --disable luau-shield001`):

```toml
[rules]
luau-shield001 = "off"
```

When the analyzer misses one of your own validation functions, declaring it
as a [sanitizer](../configuration.md#sanitizers) is better than turning the
rule off:

```toml
[[sanitizers]]
function = "RewardTokens.verify"
checks = "all"
```
