--!strict
-- Vulnerable: the pet remotes are a table of handlers connected in a loop.
-- Equip is cheap, but Summon clones a pet model on every request: an
-- exploiter fires Summon in a loop and the server spends its time creating,
-- replicating and destroying pet models.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local PetRemotes = ReplicatedStorage.Remotes.Pets
local COMPANION = ServerStorage.Pets.Dog

local handlers: { [string]: (Player, ...unknown) -> () } = {}

function handlers.Equip(player: Player, slot: unknown)
	if typeof(slot) == "number" and slot >= 1 and slot <= 3 and slot % 1 == 0 then
		player:SetAttribute("EquippedPetSlot", slot)
	end
end

function handlers.Summon(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local previous = character:FindFirstChild("Pet")
	if previous then
		previous:Destroy()
	end
	local pet = COMPANION:Clone()
	pet.Name = "Pet"
	pet.Parent = character
end

for name, handler in handlers do
	PetRemotes[name].OnServerEvent:Connect(handler) -- expect: luau-shield007
end
