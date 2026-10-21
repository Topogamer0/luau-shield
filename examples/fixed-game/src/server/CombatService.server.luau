-- Sword combat and movement abilities (sprint and blink).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Validate = require(ReplicatedStorage.Shared.Validate)
local Remotes = require(script.Parent.Modules.Remotes)

local lastSwing: { [Player]: number } = {}
local lastBlink: { [Player]: number } = {}

local function getCharacterParts(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return character:FindFirstChildOfClass("Humanoid"), root
end

-- Server-side hit detection: the first living humanoid in front of the
-- player, within sword range.
local function findTarget(character: Model, root: BasePart): Humanoid?
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local center = root.Position + root.CFrame.LookVector * (Config.SwordRange / 2)
	for _, part in workspace:GetPartBoundsInRadius(center, Config.SwordRange / 2, params) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			return humanoid
		end
	end
	return nil
end

-- The client only says "I swung"; the server decides who is hit and how hard.
Remotes.SwingSword.OnServerEvent:Connect(function(player: Player)
	local character = player.Character
	local humanoid, root = getCharacterParts(player)
	if not character or not humanoid or not root or not character:FindFirstChildOfClass("Tool") then
		return -- no character or no sword equipped
	end
	local now = os.clock()
	if humanoid.Health <= 0 or now - (lastSwing[player] or 0) < Config.SwordCooldown then
		return
	end
	lastSwing[player] = now
	local target = findTarget(character, root)
	if target then
		target:TakeDamage(Config.SwordDamage)
	end
end)

-- The client only says whether it is sprinting; the speeds are server values.
Remotes.Sprint.OnServerEvent:Connect(function(player: Player, isSprinting: unknown)
	local humanoid = getCharacterParts(player)
	if not humanoid or typeof(isSprinting) ~= "boolean" then
		return
	end
	if isSprinting then
		humanoid.WalkSpeed = Config.SprintSpeed
	else
		humanoid.WalkSpeed = Config.WalkSpeed
	end
end)

-- Blink: teleports the player to the point under the mouse, within range.
Remotes.Blink.OnServerEvent:Connect(function(player: Player, targetPosition: unknown)
	local _, root = getCharacterParts(player)
	local now = os.clock()
	if not root or now - (lastBlink[player] or 0) < Config.BlinkCooldown then
		return
	end
	if not Validate.isNearPosition(targetPosition, root.Position, Config.BlinkDistance + 1) then
		return -- not a Vector3, NaN, or too far away
	end
	lastBlink[player] = now
	root.CFrame = CFrame.new(targetPosition) * root.CFrame.Rotation
end)

Players.PlayerRemoving:Connect(function(player)
	lastSwing[player] = nil
	lastBlink[player] = nil
end)
