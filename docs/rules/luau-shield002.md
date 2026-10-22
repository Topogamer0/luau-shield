# luau-shield002: untrusted-instance-property

A value controlled by the client is written to a sensitive Instance property
(`CFrame`, `WalkSpeed`, `Health`, `Parent`, `Text`, ...) or passed to a method
that moves, damages or resizes something (`PivotTo`, `TakeDamage`,
`ApplyImpulse`, ...) without being bounded, allow-listed or validated.

| Severity | Default | Applies to |
| --- | --- | --- |
| High | Enabled | Server code (`*.server.luau` Scripts, server ModuleScripts, and replicated modules called from server code). Never LocalScripts. |

## What it detects

luau-shield002 follows untrusted values (see
[Sources of untrusted data](../analysis.md#2-sources-of-untrusted-data):
remote parameters after `player`, fields of tables sent by the client,
`player.Chatted` messages, values returned by `InvokeClient`, Knit client
methods, ...) through variables, tables, arithmetic, local functions and
required modules ([Propagation](../analysis.md#3-propagation)), and reports
them when they reach one of these sinks without enough checking.

**Property assignments** (`x.Property = value`, on any Instance):

| Kind | Properties |
| --- | --- |
| Position and movement | `Position`, `CFrame`, `Orientation`, `Rotation`, `Size`, `Velocity`, `AssemblyLinearVelocity`, `AssemblyAngularVelocity` |
| Humanoid | `Health`, `MaxHealth`, `WalkSpeed`, `JumpPower`, `JumpHeight`, `HipHeight` |
| Physics | `Anchored`, `CanCollide` |
| Hierarchy and references | `Parent`, `PrimaryPart` |
| Teams and spawning | `Team`, `TeamColor`, `Neutral`, `RespawnLocation` |
| Text | `Text` |

**Method calls** (the arguments that receive the untrusted value):

| Method | Typical receiver |
| --- | --- |
| `PivotTo(cframe)`, `SetPrimaryPartCFrame(cframe)`, `MoveTo(position)`, `TranslateBy(offset)`, `ScaleTo(scale)` | `Model`, `PVInstance`, `Humanoid` |
| `TakeDamage(amount)` | `Humanoid` |
| `ApplyImpulse(impulse)`, `ApplyAngularImpulse(impulse)` | `BasePart` |
| `SetAttribute(name, value)` (the value) | any Instance, when the attribute name is **not** a currency/stat name |

`SetAttribute("Coins", x)` and other stat-named attributes are reported by
[luau-shield001](luau-shield001.md) instead.

The receiver does not matter: setting the player's **own** character from a
client value is still a finding. Server-side movement and combat checks trust
what the server sets, so a `WalkSpeed` or a teleport chosen by the client is a
speed or teleport hack with the server's blessing.

The finding is reported on the line of the assignment or of the method call,
also when that line is in a helper function or in a required module.

## Why it is dangerous

Exploiters do not use your UI: they call `FireServer` and `InvokeServer`
directly with any arguments they like. A typical attack on a melee game:

1. The exploiter watches the remotes the game fires (any remote spy shows
   `MeleeHit:FireServer(victimUserId, 25)`).
2. They loop over `Players:GetPlayers()` and fire
   `MeleeHit:FireServer(other.UserId, 1e9)` for every player.
3. The server looks up each victim correctly, then runs
   `humanoid:TakeDamage(damage)` with the exploiter's number. The whole server
   dies in one frame, every round.

The same pattern gives teleports (`root.CFrame = clientCFrame` into the vault
or onto the finish line), permanent speed (`humanoid.WalkSpeed = 500`),
god mode (`humanoid.Health = 1e6`), flings (`part:ApplyImpulse(Vector3.new(0, 1e7, 0))`),
griefing (another player's base as the `Parent` of your furniture), joining a
hidden staff team (`player.TeamColor = staffColor`) and unfiltered text shown to
everyone (`label.Text = message`), which also breaks Roblox's text filtering
rules and gets games moderated.

## Vulnerable example

```lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage.Remotes

-- The client reports a hit and the damage it computed.
Remotes.MeleeHit.OnServerEvent:Connect(function(attacker: Player, victimUserId: number, damage: number)
	local victim = Players:GetPlayerByUserId(victimUserId)
	local character = if victim then victim.Character else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid and typeof(damage) == "number" and damage > 0 then
		humanoid:TakeDamage(damage) -- luau-shield002: no upper bound
	end
end)

-- The client picks the destination of the Blink ability.
Remotes.Blink.OnServerEvent:Connect(function(player: Player, destination: Vector3)
	local character = player.Character
	if character and typeof(destination) == "Vector3" then
		character:MoveTo(destination) -- luau-shield002: anywhere on the map
	end
end)
```

## Fixed example

```lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage.Remotes

local WEAPONS = {
	Sword = { damage = 25, range = 8 },
	Dagger = { damage = 12, range = 5 },
}
local BLINK_RANGE = 40

-- The client only says WHO it hit. Damage and range come from server data.
Remotes.MeleeHit.OnServerEvent:Connect(function(attacker: Player, victimUserId: number)
	local attackerCharacter = attacker.Character
	local tool = if attackerCharacter then attackerCharacter:FindFirstChildOfClass("Tool") else nil
	local weapon = if tool then WEAPONS[tool.Name] else nil

	local victim = Players:GetPlayerByUserId(victimUserId)
	local character = if victim and victim ~= attacker then victim.Character else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not weapon or not root or not humanoid then
		return
	end
	if attacker:DistanceFromCharacter(root.Position) > weapon.range then
		return
	end

	humanoid:TakeDamage(weapon.damage) -- server value
end)

-- The destination must be within BLINK_RANGE studs, or the handler stops.
Remotes.Blink.OnServerEvent:Connect(function(player: Player, destination: Vector3)
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not character or not root or typeof(destination) ~= "Vector3" then
		return
	end
	if (destination - root.Position).Magnitude > BLINK_RANGE then
		return
	end

	character:MoveTo(destination) -- bounded by the distance check
end)
```

A real game also needs a cooldown on both remotes; luau-shield002 is only about the
values. Handlers that call `*Async` methods, `Instance.new` or `:Clone()` need
one to pass [luau-shield007](luau-shield007.md).

## What counts as a check

The facts are described in [Checks](../analysis.md#4-checks-sanitizers). A
check only protects the code that runs **after it succeeds**: an early
`return`, `error`, `assert`, the body of an `if`, or one branch of an
`if`-expression. A check that only logs (`if tooFar then warn(...) end`) and
lets execution continue protects nothing.

Values the server computes itself are not client-controlled at all. That
includes values read from server tables or folders with a client key:
`WEAPONS[tool.Name].damage`, `Checkpoints:FindFirstChild(name).CFrame`,
`ROTATIONS[index]`.

For a client value, one of the following is enough:

**Lower and upper bound** (numbers):

```lua
humanoid.WalkSpeed = math.clamp(speed, 16, 24)

if typeof(amount) ~= "number" or amount < 0 or amount > MAX_HEAL then return end
humanoid.Health = math.clamp(humanoid.Health + amount, 0, humanoid.MaxHealth)

local isScale = t.numberConstrained(0.8, 1.25)
if not isScale(scale) then return end
character:ScaleTo(scale)
```

One bound is not enough: `math.min(x, max)` alone lets a negative heal kill a
player, and `if damage <= 0 then return end` alone lets `1e9` through.

Unlike [luau-shield001](luau-shield001.md), luau-shield002 does **not** require NaN to be rejected. For
currency, `if amount <= 0 or amount > 100 then return end` is not enough
because NaN passes both comparisons; for luau-shield002 the same check is accepted.

**Bounded vectors and CFrames**: a magnitude or distance comparison that must
hold for execution to continue, or `math.clamp` on every component:

```lua
if (destination - root.Position).Magnitude > BLINK_RANGE then return end
character:MoveTo(destination)

if velocity.Magnitude > MAX_KICK_SPEED then return end
ball.AssemblyLinearVelocity = velocity

local clamped = Vector3.new(math.clamp(impulse.X, -MAX, MAX), 0, math.clamp(impulse.Z, -MAX, MAX))
crate:ApplyImpulse(clamped)
```

Clamping only some components (`Vector3.new(clampedX, velocity.Y, clampedZ)`)
leaves the vector unbounded. Rounding or snapping (`math.floor`, a grid
`snap` function) is not a bound.

**Boolean**: once `typeof(x) == "boolean"` holds, any boolean is safe:

```lua
if typeof(closed) ~= "boolean" then return end
gate.CanCollide = closed
```

**Allow-listed**: `x == "literal"`, `ALLOWED[x]` truthy, `table.find(ALLOWED, x)`,
`folder:FindFirstChild(x)` non-nil, `t.literal(...)`, `t.keyOf(...)`. Using
the client value only as a key into a server table is the simplest fix:

```lua
local JOINABLE_TEAMS = { Red = Teams.Red, Blue = Teams.Blue }
local team = JOINABLE_TEAMS[teamName]
if not team then return end
player.Team = team
```

**Validated**: a validation function luau-shield can analyse (same file or a
resolved module), an unresolved function whose name starts with `is`,
`validate`, `verify`, `check`, `sanitize`, `assert` or `ensure` used as a
guard, a `t.strict(...)` assertion, or a
[custom sanitizer](../configuration.md#sanitizers):

```lua
-- ReplicatedStorage.Shared.Grid
function Grid.isInsidePlot(position: unknown, plotCenter: Vector3): boolean
	return typeof(position) == "Vector3" and (position - plotCenter).Magnitude <= PLOT_RADIUS
end

-- server
if not Grid.isInsidePlot(target, plot:GetPivot().Position) then return end
Plots.place(model, target)
```

Some properties need a specific fact instead of bounds:

| Sink | Enough |
| --- | --- |
| `Parent`, `Team`, `RespawnLocation`, `PrimaryPart` | ownership/location (`x:IsDescendantOf(plot)`, `x.Parent == player.Backpack`, `x:GetAttribute("Owner") == player.UserId`, a distance check, ...) or allow-listed |
| `Text` | filtered with TextService (`FilterStringAsync` + `GetNonChatStringForBroadcastAsync` / `GetChatForUserAsync` / `GetNonChatStringForUserAsync`), or allow-listed |

```lua
local plot = workspace.Plots:FindFirstChild(player.Name)
if not plot or not chest:IsDescendantOf(plot) then return end
tool.Parent = chest

local result = TextService:FilterStringAsync(name, player.UserId)
label.Text = result:GetNonChatStringForBroadcastAsync()
```

A length limit (`#name <= 20`, `message:sub(1, 60)`) is not filtering, and
`chest:IsA("Model")` is a type check, not ownership.

**Not checks:**

- Type annotations: `function(player, speed: number)` receives whatever the
  exploiter sends. Luau types are erased at runtime.
- Type checks alone: `typeof(cf) == "CFrame"`, `t.number(x)`,
  `x:IsA("Team")`.
- A check on a different value than the one that is used, for example a
  distance check on the crate being pushed instead of on the impulse.

## Limitations

- **The quality of a bound is not judged.** `math.clamp(speed, 0, 1e6)` is a
  lower and an upper bound and passes. Choose bounds that make sense for the
  game.
- **NaN is not required.** A check written as `if x < 8 or x > 32 then return end`
  lets NaN through, and a NaN position or velocity can break physics. Add
  `if x ~= x then return end` where that matters.
- **Server lookups are trusted, even when the client picks the key.**
  `player.Team = Teams:FindFirstChild(teamName)` is not reported, although the
  client can choose any existing team, including a hidden one. Look the
  value up in a table that only contains allowed entries.
- **Which Instance is modified is not checked.** luau-shield002 is about the value.
  `Players:GetPlayerByUserId(id)` is a server lookup, so damaging the player
  the client named is not reported; deciding whether the attacker may hit
  that player (range, team, line of sight) is game logic.
- **Bounding by normalisation is not recognised.** `direction.Unit * SPEED`
  is bounded in practice but is reported; use a magnitude check or
  `math.clamp` per component.
- **Sinks are recognised by name.** A field of a plain Lua table that has
  the name of a sensitive property (`state.Position = pos`) can be reported
  when luau-shield cannot tell that the table is not an Instance. Wrappers
  in packages that are not analysed (a `Movement.setSpeed` from Wally) are not
  seen: declare them as [sinks](../configuration.md#sinks) with
  `rule = "luau-shield002"`.
- **Indirect writes are not tracked.** A value stored in an attribute,
  a `ValueBase` or sent through a `BindableEvent` and applied by another
  script is lost (see [Limits](../analysis.md#6-limits)). The
  `SetAttribute` call itself is reported.

## Suppressing

Put the comment at the end of the line of the finding, or on the line
directly above it, with a reason:

```lua
humanoid.WalkSpeed = speed -- luau-shield-ignore: luau-shield002 speed is validated by the Movement package
```

To turn the rule off for the whole project, in `luau-shield.toml`:

```toml
[rules]
luau-shield002 = "off"
```

See [Suppressing findings](../configuration.md#suppressing-findings) for
file-level suppressions.
