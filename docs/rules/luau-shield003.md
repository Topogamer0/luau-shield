# luau-shield003: unverified-client-instance

An Instance sent by the client is modified, destroyed, moved or used as the
source of a reward without first checking that it belongs to the player or is
where it should be.

| Severity | Default | Applies to |
| --- | --- | --- |
| High | Enabled | Server code (`*.server.luau` Scripts, server ModuleScripts, and replicated modules called from server code). Never LocalScripts. |

## What it detects

A remote can carry references to Instances. luau-shield003 follows every value that
comes from the client (see
[Sources of untrusted data](../analysis.md#2-sources-of-untrusted-data): the
parameters of `OnServerEvent` / `OnServerInvoke` handlers after `player`,
**fields of tables** sent by the client such as `data.target`, values returned
by `InvokeClient`, Knit client methods) through variables, tables, local
functions and required modules ([Propagation](../analysis.md#3-propagation)),
and reports the first time such a value is **used as an Instance** before its
ownership or location has been checked.

These are uses:

| Use | Examples |
| --- | --- |
| Calling a method on it, or on something reached through it, other than a read-only query or a string method | `part:Destroy()`, `tool:Clone()`, `model:PivotTo(cf)`, `door:SetAttribute("Open", true)`, `hitPart.Parent:FindFirstChildOfClass("Humanoid"):TakeDamage(20)` |
| Assigning any property on it, or on something reached through it | `door.CanCollide = false`, `tool.Parent = player.Character`, `part.Color = color`, `tool.Handle.CanCollide = false` |
| Passing it to `Debris:AddItem`, `CollectionService:AddTag` or `CollectionService:RemoveTag` | `Debris:AddItem(crate, 1)`, `CollectionService:RemoveTag(coin, "Coin")` |
| Using data read from it in an [luau-shield001](luau-shield001.md) or [luau-shield002](luau-shield002.md) sink | `coins.Value += chest:GetAttribute("Reward")`, `cash.Value += tool.Price.Value` (once `tool` is known to be an Instance), `humanoid.WalkSpeed = pad:GetAttribute("Speed")` |

The last kind is reported as luau-shield003 instead of luau-shield001/luau-shield002: the attribute or
`ValueBase` was set by the server, so the *amount* is not client data, but the
client chose *which* Instance it is read from.

These are **not** uses:

- read-only queries: `IsA`, `IsDescendantOf`, `IsAncestorOf`, `FindFirstChild`,
  `FindFirstChildOfClass`, `FindFirstChildWhichIsA`, `FindFirstAncestor`,
  `FindFirstAncestorOfClass`, `FindFirstAncestorWhichIsA`, `WaitForChild`,
  `GetAttribute`, `GetAttributes`, `GetChildren`, `GetDescendants`,
  `GetFullName`, `GetPivot`, `GetBoundingBox`, `GetExtentsSize`, `GetMass`,
  `HasTag`, `GetTags`, `GetPropertyChangedSignal`, `GetAttributeChangedSignal`;
- string methods (`sub`, `lower`, `upper`, `match`, `find`, `gsub`, `gmatch`,
  `len`, `rep`, `reverse`, `split`, `byte`, `format`): the value may simply be a
  string;
- reading properties for anything other than a luau-shield001/luau-shield002 sink (printing,
  returning a description to the client, comparing).

There is **one finding per untrusted value per handler**, on the line of the
first use in execution order. When that use is inside a helper function or a
required module, the finding is reported there. A check placed before the
first use protects every later use as well.

Two related cases are deliberately left to other rules or not reported:

- An Instance found by the **server** with a client key is a server value,
  never a luau-shield003: `player.Backpack:FindFirstChild(toolName)`,
  `Shop.Items:FindFirstChild(itemName)`, `Players:GetPlayerByUserId(id)`.
  Whatever the client sends, the result can only be one of the objects the
  server searched.
- A client Instance used as the **value** of a property, as in
  `weld.Parent = clientPart`, is reported by [luau-shield002](luau-shield002.md) (`Parent`
  needs ownership) when it was not checked. luau-shield003 reports the first use of
  `clientPart` itself.

## Why it is dangerous

From the client, an exploiter can pass **any Instance their client can see**
to a remote: everything in `Workspace` (other players' characters and the
tools they are holding, every plot, every door, every coin), everything in
`ReplicatedStorage` (shop templates, effects), and their own `PlayerGui`. A
remote spy shows them which remotes take an Instance, and the rest is a loop.

A typical attack on a simulator:

1. The exploiter sees `CollectCoin:FireServer(coin)` when they walk over a
   coin.
2. They run `CollectionService:GetTagged("Coin")` on their client and fire
   `CollectCoin` once for each coin.
3. The server checks that the part is tagged `"Coin"` (true for all of them)
   and pays every coin on the map to a player standing at spawn. They repeat
   it each time the coins respawn: an autofarm with no movement at all.

The same mistake lets exploiters sell or equip the tool another player is
holding (it lives in that player's character), equip the shop's templates
from `ReplicatedStorage` for free, open the VIP door or the doors of other
players' houses, delete or repaint other players' builds, unanchor the lobby,
and break every "breakable" wall of every team base from across the map.

## Vulnerable example

```lua
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage.Remotes

-- The client reports the coin it touched.
Remotes.CollectCoin.OnServerEvent:Connect(function(player: Player, coin: BasePart)
	if typeof(coin) ~= "Instance" or not CollectionService:HasTag(coin, "Coin") then
		return
	end
	CollectionService:RemoveTag(coin, "Coin") -- luau-shield003: any coin, from anywhere
	coin:Destroy()
	player.leaderstats.Coins.Value += 1
end)

-- The client sells the tool selected in the inventory UI.
Remotes.SellTool.OnServerEvent:Connect(function(player: Player, tool: Tool)
	if typeof(tool) ~= "Instance" or not tool:IsA("Tool") then
		return
	end
	local price = tool:GetAttribute("SellPrice")
	if typeof(price) ~= "number" then
		return
	end
	player.leaderstats.Cash.Value += price -- luau-shield003: someone else's tool
	tool:Destroy()
end)
```

## Fixed example

```lua
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage.Remotes

local PICKUP_RANGE = 10

-- The coin must be next to the player's character.
Remotes.CollectCoin.OnServerEvent:Connect(function(player: Player, coin: BasePart)
	if typeof(coin) ~= "Instance" or not CollectionService:HasTag(coin, "Coin") then
		return
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not root or (coin.Position - root.Position).Magnitude > PICKUP_RANGE then
		return
	end
	CollectionService:RemoveTag(coin, "Coin")
	coin:Destroy()
	player.leaderstats.Coins.Value += 1
end)

-- Only tools in the player's own Backpack can be sold.
Remotes.SellTool.OnServerEvent:Connect(function(player: Player, tool: Tool)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack or typeof(tool) ~= "Instance" or tool.Parent ~= backpack then
		return
	end
	if not tool:IsA("Tool") then
		return
	end
	local price = tool:GetAttribute("SellPrice")
	if typeof(price) ~= "number" then
		return
	end
	player.leaderstats.Cash.Value += price
	tool:Destroy()
end)
```

Removing the tag before destroying the coin also stops the same coin from
being paid twice when the remote is fired several times in a row. Even
simpler for selling: let the client send the tool's **name** and look it up
with `backpack:FindFirstChild(toolName)`, which is a server lookup.

## What counts as a check

The facts are described in [Checks](../analysis.md#4-checks-sanitizers). A
check only protects the code that runs **after it succeeds**: an early
`return`, `error`, `assert`, or the body of an `if`. For luau-shield003 one of these is
enough:

**Ownership or location.** The Instance is inside something that belongs to
the player, points back to the player, or is within reach of the character:

```lua
-- inside the player's character, Backpack or plot
if not tool:IsDescendantOf(player.Character) then return end
if tool.Parent ~= player.Backpack then return end
if not part:IsDescendantOf(workspace.Plots[player.Name]) then return end
if not plot:IsAncestorOf(part) then return end
if part:FindFirstAncestorOfClass("Model") ~= player.Character then return end

-- the Instance names its owner
if Players:GetPlayerFromCharacter(accessory.Parent) ~= player then return end
if model:GetAttribute("Owner") ~= player.UserId then return end
if model.Owner.Value ~= player then return end

-- the Instance is within reach
if (coin.Position - root.Position).Magnitude > 10 then return end
if player:DistanceFromCharacter(chest.Position) > 12 then return end
```

The container you compare with must be a server value (`player.Character`,
a plot the server looked up). `part:IsDescendantOf(otherClientInstance)`
proves nothing: the exploiter sends `(otherPlot, block)` or
`(workspace, anything)`. The same goes for the reference point of a distance
check: `(ore.Position - hitPosition).Magnitude < 4` with a `hitPosition` sent
by the client only proves that the two arguments agree with each other
(the exploiter sends `ore.Position`). Measure from the character's
`HumanoidRootPart`.

**Allow-listed.** The Instance is one of a fixed set the server knows:

```lua
local PUBLIC_DOORS = { workspace.Lobby.FrontDoor, workspace.Lobby.ShopDoor }
if not table.find(PUBLIC_DOORS, door) then return end

local SPAWN_PADS = { [workspace.Spawns.PadA] = true, [workspace.Spawns.PadB] = true }
if not SPAWN_PADS[pad] then return end
```

**Validated.** A validation function that luau-shield analyses (same file or a
resolved module) and that checks ownership or location when it returns a
truthy value; an unresolved function whose name starts with `is`, `validate`,
`verify`, `check`, `sanitize`, `assert` or `ensure` used as a guard; or a
[custom sanitizer](../configuration.md#sanitizers) with `checks = "all"`,
`["ownership"]` or `["allowlist"]`:

```lua
-- ReplicatedStorage.Shared.Validate (analysed: what it checks is what counts)
function Validate.isOwnedFurniture(value: unknown, player: Player): boolean
	return typeof(value) == "Instance" and value:GetAttribute("Owner") == player.UserId
end

-- server
if not Validate.isOwnedFurniture(model, player) then return end
Furniture.pickUp(player, model)
```

A resolved function is judged by its body, not by its name: an
`isFurniture(value)` that only does `value:IsA("Model")` gives a type fact,
and the model is still unverified.

**Not checks:**

- Type checks: `typeof(x) == "Instance"`, `x:IsA("Tool")`,
  `t.instanceIsA("Tool")(x)`, `CollectionService:HasTag(x, "Coin")`,
  `x:HasTag("Coin")`. They say *what* the object is, and every tool, coin or
  door of the game passes them.
- Checks of what the Instance claims to be: `x.Name == "Door"`,
  `x:GetAttribute("Breakable") == true`.
- Type annotations: `function(player, tool: Tool)` receives whatever the
  exploiter sends. Luau types are erased at runtime.
- Checks on something else, such as the player's character being alive, or a
  cooldown. They are useful, but they do not tie the Instance to the player.
- Checks that do not stop the handler. `if car.Owner.Value ~= player then
  warn(...) end` followed by `car:Destroy()` destroys the car anyway. A check
  written inside one branch (`if action == "Equip" then ... end`) does not
  protect the other branches either, and the client chooses the branch: do
  the check once, before dispatching.

Values that need checking for other rules keep their own requirements: a
number read from a verified Instance is server data, but a number sent by the
client next to it still needs the [luau-shield001](luau-shield001.md) checks (including NaN
rejection) before it goes into `leaderstats`.

**Admin-only code.** Admin tools act on Instances the admin picked (kick a
player, delete a build). After a [permission check](../configuration.md#guards)
on the sender, these findings are reported as `info`, hidden by default. The
same handler's unguarded path is still reported.

## Limitations

- **The quality of the anchor is not judged.** `part:IsDescendantOf(workspace)`
  or `part:IsDescendantOf(workspace.Plots)` is accepted as a location check,
  although every part of the map (or every plot) passes it. A distance check
  with a huge range is accepted too. Anchor the check to the player's own
  character, Backpack or plot.
- **Server lookups are trusted, even when they search too widely.**
  `workspace:FindFirstChild(name, true)` lets the client pick any named
  Instance in the game and is not reported. Search a container that only holds
  what the player may use.
- **Lookups keyed by an Instance's data are server values.** A handler that
  only does `coins.Value += CHEST_REWARDS[chest.Name]` with a client-chosen
  `chest` (and never modifies the chest) is not reported, although the client
  picked which reward it gets.
- **Instances kept between events are not followed.** A part stored in a
  server table by a `Select` remote (`selected[player] = part`) and destroyed
  later by a `Delete` remote is not reported; check ownership where the part
  arrives. Values passed through `BindableEvent`s, attributes or `ObjectValue`s
  are not followed either (see [Limits](../analysis.md#6-limits)).
- **Read-only methods come from a fixed list.** A harmless method that is not
  in the list above (for example `GetDebugId()`) counts as a use.
- **Ownership is followed one step.** A client plot whose owner was checked
  (`plot:GetAttribute("Owner") == player.UserId`) is a valid anchor for
  `block:IsDescendantOf(plot)`, and checking a value read from the Instance
  (`local owner = model:FindFirstChild("Owner")`, then `owner.Value == player`)
  verifies `model`. Longer chains through several locals are not followed.
- **Distance checks trust the character's position.** The client controls
  the physics of its own character, so an exploiter can teleport next to each
  target before firing the remote. A distance check stops "from anywhere"
  attacks, not a teleporting autofarm; pair it with server-side movement
  checks for valuable actions. Note also that `player:DistanceFromCharacter()`
  measures from the Head and returns `0` when the character has no Head, so
  check that the Head exists (or measure from the `HumanoidRootPart`).
- **Ownership is not permission.** luau-shield003 checks that the Instance belongs to
  the player or is near them, not that the action is allowed right now: a
  chest the player stands next to can still be opened twice if the handler
  does not remember it. That part is game logic.

## Suppressing

Put the comment at the end of the line of the finding, or on the line
directly above it, with a reason:

```lua
door.CanCollide = false -- luau-shield-ignore: luau-shield003 doors are registered and checked by DoorRegistry
```

To turn the rule off for the whole project, in `luau-shield.toml`:

```toml
[rules]
luau-shield003 = "off"
```

See [Suppressing findings](../configuration.md#suppressing-findings) for
file-level suppressions (`-- luau-shield-ignore-file: luau-shield003 <reason>`).
