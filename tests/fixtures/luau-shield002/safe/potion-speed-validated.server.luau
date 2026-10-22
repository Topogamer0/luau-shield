--!strict
-- Speed potions, fixed: the multiplier sent by the client is validated with a
-- t checker (t.numberConstrained gives type, lower and upper bound) before
-- the method of the Potions table writes it to the "Speed" attribute.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local t = require(ReplicatedStorage.Packages.t)

local DrinkPotion = ReplicatedStorage.Remotes.DrinkPotion :: RemoteEvent

local POTION_DURATION = 15
local isSpeedMultiplier = t.numberConstrained(1, 2)

local Potions = {}

function Potions:applySpeed(character: Model, multiplier: number)
	character:SetAttribute("Speed", multiplier)
	task.delay(POTION_DURATION, function()
		character:SetAttribute("Speed", 1)
	end)
end

DrinkPotion.OnServerEvent:Connect(function(player: Player, multiplier: number)
	local character = player.Character
	if not character or not isSpeedMultiplier(multiplier) then
		return
	end

	Potions:applySpeed(character, multiplier)
end)
