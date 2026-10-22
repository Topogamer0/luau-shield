-- Lobby features: fireworks, the bug report board and the analytics events
-- sent by the client UI. Every remote has a per-player cooldown.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Validate = require(ReplicatedStorage.Shared.Validate)
local Analytics = require(script.Parent.Modules.Analytics)
local Remotes = require(script.Parent.Modules.Remotes)

local effects = ServerStorage:WaitForChild("Effects")

local COOLDOWNS = { firework = 3, bugReport = 60, analytics = 1 }
local lastUse: { [string]: { [Player]: number } } = { firework = {}, bugReport = {}, analytics = {} }

-- True when `player` used `action` too recently; otherwise records the use.
local function onCooldown(player: Player, action: string): boolean
	local now = os.clock()
	local last = lastUse[action][player]
	if last and now - last < COOLDOWNS[action] then
		return true
	end
	lastUse[action][player] = now
	return false
end

-- Launches a firework rocket above the player.
Remotes.LaunchFirework.OnServerEvent:Connect(function(player: Player, effectName: unknown)
	if onCooldown(player, "firework") or not table.find(Config.Fireworks, effectName) then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local effect = effects:FindFirstChild(effectName)
	if not root or not effect then
		return
	end
	local rocket = Instance.new("Part")
	rocket.Name = "Firework"
	rocket.Size = Vector3.new(0.6, 2, 0.6)
	rocket.CFrame = root.CFrame + Vector3.new(0, 4, 0)
	rocket.CanCollide = false
	rocket.AssemblyLinearVelocity = Vector3.new(0, 60, 0)
	effect:Clone().Parent = rocket
	rocket.Parent = workspace
	Debris:AddItem(rocket, Config.FireworkLifetime)
end)

Remotes.SubmitBugReport.OnServerEvent:Connect(function(player: Player, category: unknown, text: unknown)
	if onCooldown(player, "bugReport") then
		return
	end
	if not table.find(Config.BugCategories, category) or not Validate.isShortString(text, Config.BugReportMaxLength) then
		return
	end
	Analytics.reportBug(player, category, text)
end)

Remotes.TrackEvent.OnServerEvent:Connect(function(player: Player, eventName: unknown, detail: unknown)
	if onCooldown(player, "analytics") then
		return
	end
	if not table.find(Config.AnalyticsEvents, eventName) or not Validate.isShortString(detail, 64) then
		return
	end
	Analytics.track(player, eventName, detail)
end)

Players.PlayerRemoving:Connect(function(player)
	for _, uses in lastUse do
		uses[player] = nil
	end
end)
