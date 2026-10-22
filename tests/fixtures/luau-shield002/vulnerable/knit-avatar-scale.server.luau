--!strict
-- Avatar customisation with Knit: the size slider of the wardrobe UI calls
-- AvatarService:SetScale. Knit client methods are remote handlers: every
-- parameter after `player` is client-controlled.
-- "scale <= 0" is a lower bound only.
--
-- Exploit: SetScale(80) for a giant that blocks the map and reaches every
-- hitbox, or SetScale(0.01) for a character too small to be hit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local AvatarService = Knit.CreateService({
	Name = "AvatarService",
	Client = {},
})

function AvatarService.Client:SetScale(player: Player, scale: number): boolean
	local character = player.Character
	if not character or typeof(scale) ~= "number" or scale <= 0 then
		return false
	end

	character:ScaleTo(scale) -- expect: luau-shield002
	return true
end

Knit.Start():catch(warn)
