--!strict
-- Speed potions: when the player drinks a potion, the client reads the
-- multiplier from the potion's config and sends it to the server, which sets
-- the "Speed" attribute on the character. The movement script derives
-- WalkSpeed from that attribute every frame.
-- The sink is inside a method of the local Potions table.
--
-- Exploit: send multiplier = 40 and re-fire the remote every 15 seconds:
-- permanent 40x speed that the anti-cheat considers legitimate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DrinkPotion = ReplicatedStorage.Remotes.DrinkPotion :: RemoteEvent

local POTION_DURATION = 15

local Potions = {}

function Potions:applySpeed(character: Model, multiplier: number)
	character:SetAttribute("Speed", multiplier) -- expect: luau-shield002
	task.delay(POTION_DURATION, function()
		character:SetAttribute("Speed", 1)
	end)
end

DrinkPotion.OnServerEvent:Connect(function(player: Player, multiplier: number)
	local character = player.Character
	if not character or typeof(multiplier) ~= "number" then
		return
	end

	Potions:applySpeed(character, multiplier)
end)
