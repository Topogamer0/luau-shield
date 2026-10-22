--!strict
-- Kart racing, fixed: each input axis is checked with
-- t.numberConstrained(-1, 1). t.tuple applies the first checker to the first
-- argument and the second to the second, so throttle and steer both get a
-- type, a lower and an upper bound before they are stored on the kart.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local t = require(ReplicatedStorage.Packages.t)

local KartInput = ReplicatedStorage.Remotes.KartInput :: UnreliableRemoteEvent

local isAxis = t.numberConstrained(-1, 1)
local checkInput = t.tuple(isAxis, isAxis)

KartInput.OnServerEvent:Connect(function(player: Player, throttle: number, steer: number)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local seat = if humanoid then humanoid.SeatPart else nil
	if not seat or not seat:IsA("VehicleSeat") or not checkInput(throttle, steer) then
		return
	end

	local kart = seat.Parent :: Model
	kart:SetAttribute("Throttle", throttle)
	kart:SetAttribute("Steer", steer)
end)
