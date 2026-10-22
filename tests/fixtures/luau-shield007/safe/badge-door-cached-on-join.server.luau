--!strict
-- Safe: the badge is checked once when the player joins (and recorded when it
-- is awarded in game). The OpenSecretDoor handler only reads the cached
-- answer, so it makes no web request however often it is fired.
local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CAVE_BADGE_ID = 2124567890
local OpenSecretDoor = ReplicatedStorage.Remotes.OpenSecretDoor :: RemoteEvent
local hasCaveBadge: { [Player]: boolean } = {}

Players.PlayerAdded:Connect(function(player: Player)
	local ok, hasBadge = pcall(function()
		return BadgeService:UserHasBadgeAsync(player.UserId, CAVE_BADGE_ID)
	end)
	hasCaveBadge[player] = ok and hasBadge == true
end)

workspace.Cave.Entrance.Touched:Connect(function(hit: BasePart)
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if player and not hasCaveBadge[player] then
		hasCaveBadge[player] = true
		pcall(function()
			BadgeService:AwardBadge(player.UserId, CAVE_BADGE_ID)
		end)
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	hasCaveBadge[player] = nil
end)

local function onOpenSecretDoor(player: Player)
	if hasCaveBadge[player] then
		player:SetAttribute("SecretDoorOpen", true)
	end
end

OpenSecretDoor.OnServerEvent:Connect(onOpenSecretDoor)
