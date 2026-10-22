-- Vehicle spawner: the "despawn" button of the car menu fires DespawnCar with
-- the player's car. The developer added an ownership check on the car's
-- "Owner" ObjectValue, but it only logs a warning for the anti-cheat
-- dashboard and then carries on: without a `return`, the check protects
-- nothing that comes after it.
--
-- Exploit: in a racing game, fire DespawnCar with every other player's car
-- during the race. All of them vanish; the warnings are read the next day.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DespawnCar = ReplicatedStorage.Remotes.DespawnCar

local spawnedCars = {}

DespawnCar.OnServerEvent:Connect(function(player, car)
	if typeof(car) ~= "Instance" or not car:IsA("Model") then
		return
	end
	if car.Owner.Value ~= player then
		warn(`[AntiCheat] {player.Name} despawned a car they do not own: {car:GetFullName()}`)
	end

	car:Destroy() -- expect: luau-shield003
	spawnedCars[player] = nil
end)
