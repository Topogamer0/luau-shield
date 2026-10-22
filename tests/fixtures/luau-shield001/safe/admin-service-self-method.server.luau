-- Safe (v0.2.0 review): `self:IsAdmin(player)` inside an AdminService is a permission check (info).
-- OOP-style admin service: commands check `self:IsAdmin(player)`.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local AdminService = {}
AdminService.__index = AdminService

local ADMIN_IDS = { [12345] = true, [67890] = true }
local data = {}

function AdminService:IsAdmin(player)
	return ADMIN_IDS[player.UserId] == true
end

function AdminService:SetCoins(player, targetName, amount)
	if not self:IsAdmin(player) then
		return
	end
	local target = Players:FindFirstChild(targetName)
	if target then
		data[target].Coins = amount
	end
end

ReplicatedStorage.Remotes.SetCoins.OnServerEvent:Connect(function(player, targetName, amount)
	AdminService:SetCoins(player, targetName, amount)
end)
