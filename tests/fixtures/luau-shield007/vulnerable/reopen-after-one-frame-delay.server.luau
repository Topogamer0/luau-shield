-- Vulnerable (v0.2.0 review): a delay of one frame (under 0.1 s) is no limit.
-- Equip a pet: tested and changed before the clone, but the state is put
-- back by task.delay(1 / 60, ...), which runs as soon as the handler finishes: the next request
-- finds the state open again and clones another pet.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local EquipPet = ReplicatedStorage.Remotes.EquipPet
local PetModel = ServerStorage.Pets.Dog
local state: { [Player]: string } = {}

EquipPet.OnServerEvent:Connect(function(player: Player) -- expect: luau-shield007
	if state[player] ~= "Idle" then
		return
	end
	state[player] = "Equipping"
	task.delay(1 / 60, function()
		state[player] = "Idle"
	end)
	local pet = PetModel:Clone()
	pet.Parent = workspace
end)
