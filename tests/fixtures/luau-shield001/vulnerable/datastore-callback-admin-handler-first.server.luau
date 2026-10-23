-- Vulnerable (v0.2.0 review): a DataStore callback shared by an admin handler and a public one is analysed for both.
-- luau-shield007 variant: the DataStore write sits in a callback passed to an
-- unresolved queue library; the admin handler reaches it first.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")
local Admins = require(ServerScriptService.Admins)
local SaveQueue = require(ServerScriptService.SaveQueue)
local store = DataStoreService:GetDataStore("Stats")

local function saveStat(player, stat)
	SaveQueue:Enqueue(function()
		store:SetAsync(player.UserId .. "_" .. stat, os.time()) -- expect: luau-shield001
	end)
end

ReplicatedStorage.Remotes.AdminTouchStat.OnServerEvent:Connect(function(player, stat)
	if not Admins.isAdmin(player) then
		return
	end
	saveStat(player, stat)
end)

ReplicatedStorage.Remotes.TouchStat.OnServerEvent:Connect(function(player, stat)
	saveStat(player, stat)
end)
