-- Vulnerable (v0.2.0 review): `task.delay(nil, f)` does not wait.
-- Equip a pet: tested and changed before the clone, but the state is put
-- back by task.delay(nil, ...), which runs as soon as the handler finishes: the next request
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
	task.delay(nil, function()
		state[player] = "Idle"
	end)
	local pet = PetModel:Clone()
	pet.Parent = workspace
end)
