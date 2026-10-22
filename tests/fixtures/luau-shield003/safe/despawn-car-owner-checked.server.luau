-- Vehicle spawner, fixed: the warning is still logged for the anti-cheat
-- dashboard, but the handler now returns. Only a car whose "Owner"
-- ObjectValue (set by the spawner) is this player can be despawned.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DespawnCar = ReplicatedStorage.Remotes.DespawnCar

local spawnedCars = {}

DespawnCar.OnServerEvent:Connect(function(player, car)
	if typeof(car) ~= "Instance" or not car:IsA("Model") then
		return
	end
	if car.Owner.Value ~= player then
		warn(`[AntiCheat] {player.Name} tried to despawn a car they do not own: {car:GetFullName()}`)
		return
	end

	car:Destroy()
	spawnedCars[player] = nil
end)
