--!strict
-- Speed potions, fixed: the client no longer sends a multiplier, it only says
-- "drink the potion I am holding". The server finds the equipped Tool in the
-- player's own character (a server lookup), reads the multiplier from its own
-- POTIONS table and destroys the potion. The sink in the method of the Potions
-- table is the same as in the vulnerable version, but the value is server data,
-- and the effect cannot be renewed for free by re-firing the remote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DrinkPotion = ReplicatedStorage.Remotes.DrinkPotion :: RemoteEvent

type PotionConfig = {
	multiplier: number,
}

local POTION_DURATION = 15
local POTIONS: { [string]: PotionConfig } = {
	SwiftPotion = { multiplier = 1.5 },
	HastePotion = { multiplier = 2 },
}

local Potions = {}

function Potions:applySpeed(character: Model, multiplier: number)
	character:SetAttribute("Speed", multiplier)
	task.delay(POTION_DURATION, function()
		character:SetAttribute("Speed", 1)
	end)
end

DrinkPotion.OnServerEvent:Connect(function(player: Player)
	local character = player.Character
	local potion = if character then character:FindFirstChildOfClass("Tool") else nil
	local config = if potion then POTIONS[potion.Name] else nil
	if not character or not potion or not config then
		return
	end

	potion:Destroy()
	Potions:applySpeed(character, config.multiplier)
end)
