-- Vulnerable (v0.2.0 review): text shown to players must be filtered even when an admin typed it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local Admins = require(ServerScriptService.Admins)
local store = DataStoreService:GetDataStore("PlayerData")
local data = {}
ReplicatedStorage.Remotes.AdminAnnounce.OnServerEvent:Connect(function(player, text)
	if not Admins.isAdmin(player) then
		return
	end
	workspace.Board.SurfaceGui.TextLabel.Text = text -- expect: luau-shield002
end)
