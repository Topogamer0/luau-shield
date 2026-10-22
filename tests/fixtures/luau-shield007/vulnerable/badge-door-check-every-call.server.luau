--!strict
-- Vulnerable: the secret door asks the badge web API on every request whether
-- the player has the "Found the cave" badge. BadgeService requests are
-- throttled per server: an exploiter firing OpenSecretDoor in a loop makes
-- the badge checks (and badge awards) of every other player fail.
local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CAVE_BADGE_ID = 2124567890
local OpenSecretDoor = ReplicatedStorage.Remotes.OpenSecretDoor :: RemoteEvent

local function onOpenSecretDoor(player: Player)
	local ok, hasBadge = pcall(function()
		return BadgeService:UserHasBadgeAsync(player.UserId, CAVE_BADGE_ID)
	end)
	if ok and hasBadge then
		player:SetAttribute("SecretDoorOpen", true)
	end
end

OpenSecretDoor.OnServerEvent:Connect(onOpenSecretDoor) -- expect: luau-shield007
