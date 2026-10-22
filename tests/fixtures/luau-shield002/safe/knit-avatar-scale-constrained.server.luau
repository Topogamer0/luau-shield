--!strict
-- Avatar customisation with Knit, fixed: t.strict turns the checker into an
-- assertion, so SetScale errors (and the client's promise rejects) unless the
-- scale is a number between 0.8 and 1.25.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local t = require(ReplicatedStorage.Packages.t)

local MIN_SCALE = 0.8
local MAX_SCALE = 1.25
local assertScale = t.strict(t.numberConstrained(MIN_SCALE, MAX_SCALE))

local AvatarService = Knit.CreateService({
	Name = "AvatarService",
	Client = {},
})

function AvatarService.Client:SetScale(player: Player, scale: number): boolean
	assertScale(scale)

	local character = player.Character
	if not character then
		return false
	end

	character:ScaleTo(scale)
	return true
end

Knit.Start():catch(warn)
