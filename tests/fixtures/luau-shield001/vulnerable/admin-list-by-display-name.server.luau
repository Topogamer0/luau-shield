-- Vulnerable (v0.2.0 review): display names are chosen by the player; `isAdmin(player.DisplayName)` proves nothing.
-- The admin list is keyed by display name. Display names are chosen by the
-- player and are not unique: anyone renames themselves "Builderman" and
-- passes the check.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ADMINS = { Builderman = true }
local data = {}

local function isAdmin(name)
	return ADMINS[name] == true
end

ReplicatedStorage.Remotes.AdminSetCoins.OnServerEvent:Connect(function(player, coins)
	if not isAdmin(player.DisplayName) then
		return
	end
	data[player].Coins = coins -- expect: luau-shield001
end)
