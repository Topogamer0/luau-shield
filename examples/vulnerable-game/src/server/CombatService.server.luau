-- Sword combat and movement abilities (sprint and blink).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(script.Parent.Modules.Remotes)

local lastBlink: { [Player]: number } = {}

local function getCharacterParts(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return character:FindFirstChildOfClass("Humanoid"), root
end

-- Hit detection runs on the client so the sword feels responsive: the client
-- reports the humanoid it hit and the damage of the sword.
Remotes.SwingSword.OnServerEvent:Connect(function(player: Player, target: Humanoid, damage: number)
	local character = player.Character
	if not character or not character:FindFirstChildOfClass("Tool") then
		return -- no sword equipped
	end
	if typeof(target) ~= "Instance" or not target:IsA("Humanoid") then
		return
	end
	target:TakeDamage(damage)
end)

Remotes.Sprint.OnServerEvent:Connect(function(player: Player, speed: number)
	local humanoid = getCharacterParts(player)
	if humanoid then
		humanoid.WalkSpeed = speed
	end
end)

-- Blink: teleports the player to the point under the mouse.
Remotes.Blink.OnServerEvent:Connect(function(player: Player, targetPosition: Vector3)
	local _, root = getCharacterParts(player)
	local now = os.clock()
	if not root or now - (lastBlink[player] or 0) < Config.BlinkCooldown then
		return
	end
	lastBlink[player] = now
	root.CFrame = CFrame.new(targetPosition) * root.CFrame.Rotation
end)

Players.PlayerRemoving:Connect(function(player)
	lastBlink[player] = nil
end)
