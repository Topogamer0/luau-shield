-- Vulnerable (v0.2.0 review): a remote handler connected by a helper from an admin path and from a public one.
-- Giveaways: an admin can start one with any amount; a "host" feature added
-- later lets any player start one too (and choose the amount). Both go
-- through `openGiveaway`, which connects the claim handler.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Admins = require(ServerScriptService.Admins)
local Remotes = ReplicatedStorage.Remotes
local data = {}

local function openGiveaway(amount)
	local claimed = {}
	Remotes.ClaimGiveaway.OnServerEvent:Connect(function(player)
		if claimed[player] then
			return
		end
		claimed[player] = true
		data[player].Coins += amount -- expect: luau-shield001
	end)
end

Remotes.AdminStartGiveaway.OnServerEvent:Connect(function(player, amount)
	if not Admins.isAdmin(player) then
		return
	end
	openGiveaway(amount)
end)

Remotes.HostGiveaway.OnServerEvent:Connect(function(player, amount)
	openGiveaway(amount)
end)
