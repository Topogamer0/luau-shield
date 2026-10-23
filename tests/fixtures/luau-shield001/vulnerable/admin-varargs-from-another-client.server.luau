-- Vulnerable (v0.2.0 review): `...` of a helper holds another client's answer, even after the admin check.
-- An admin asks a target player's client for its local stats and saves the
-- answer. The answer comes from the TARGET's client (any player), not from
-- the admin: it is client-controlled whoever asked for it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Admins = require(ServerScriptService.Admins)
local data = {}

local function record(target, ...)
	local coins = ...
	data[target].Coins = coins -- expect: luau-shield001
end

local function recordFixed(target, coins)
	data[target].Gems = coins -- expect: luau-shield001
end

ReplicatedStorage.Remotes.AdminSync.OnServerEvent:Connect(function(admin, targetUserId)
	if not Admins.isAdmin(admin) then
		return
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target then
		return
	end
	record(target, ReplicatedStorage.Remotes.GetLocalCoins:InvokeClient(target)) -- expect: luau-shield006
	recordFixed(target, ReplicatedStorage.Remotes.GetLocalCoins:InvokeClient(target)) -- expect: luau-shield006
end)
