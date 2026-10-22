-- Safe (v0.2.0 review): Knit's `self.Server:IsAdmin(player)` is a permission check (info).
-- Knit service: the client method checks `self.Server:IsAdmin(player)`.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local data = {}
local ADMIN_IDS = { [12345] = true }

local AdminService = Knit.CreateService({
	Name = "AdminService",
	Client = {},
})

function AdminService:IsAdmin(player)
	return ADMIN_IDS[player.UserId] == true
end

function AdminService.Client:SetCoins(player, userId, amount)
	if not self.Server:IsAdmin(player) then
		return
	end
	data[userId].Coins = amount
end

function AdminService.Client:SetGems(player, userId, amount)
	if not AdminService:IsAdmin(player) then
		return
	end
	data[userId].Gems = amount
end

return AdminService
