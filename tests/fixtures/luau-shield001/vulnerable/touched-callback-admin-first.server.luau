-- Vulnerable (v0.2.0 review): a pickup callback created by an admin command and by any player.
-- Coin drops: an admin can spawn a drop of any value; players can also drop
-- coins for others. The pickup's Touched listener is created by one helper.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Admins = require(ServerScriptService.Admins)
local data = {}

local function spawnDrop(position, amount)
	local part = Instance.new("Part")
	part.Position = Vector3.new(0, 10, 0)
	part.Parent = workspace
	part.Touched:Connect(function(hit)
		local picker = Players:GetPlayerFromCharacter(hit.Parent)
		if picker then
			part:Destroy()
			data[picker].Coins += amount -- expect: luau-shield001
		end
	end)
end

ReplicatedStorage.Remotes.AdminSpawnDrop.OnServerEvent:Connect(function(player, amount)
	if not Admins.isAdmin(player) then
		return
	end
	spawnDrop(player.Character:GetPivot().Position, amount)
end)

ReplicatedStorage.Remotes.DropCoins.OnServerEvent:Connect(function(player, amount) -- expect: luau-shield007
	spawnDrop(player.Character:GetPivot().Position, amount)
end)
