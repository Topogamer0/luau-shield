--!strict
-- Kart racing: the driver's client sends its throttle and steering input
-- every frame over an UnreliableRemoteEvent, and the server stores them as
-- attributes of the kart; a server-side drive loop multiplies the kart's top
-- speed by the Throttle attribute. The kart is found on the server from the
-- seat the driver sits in, but t.tuple(t.number, t.number) only checks types.
--
-- Exploit: send throttle = 25 and drive at 25 times the top speed. The kart
-- is moved by the server, so the movement anti-cheat never looks at it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local t = require(ReplicatedStorage.Packages.t)

local KartInput = ReplicatedStorage.Remotes.KartInput :: UnreliableRemoteEvent

local checkInput = t.tuple(t.number, t.number)

KartInput.OnServerEvent:Connect(function(player: Player, throttle: number, steer: number)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local seat = if humanoid then humanoid.SeatPart else nil
	if not seat or not seat:IsA("VehicleSeat") or not checkInput(throttle, steer) then
		return
	end

	local kart = seat.Parent :: Model
	kart:SetAttribute("Throttle", throttle) -- expect: luau-shield002
	kart:SetAttribute("Steer", steer) -- expect: luau-shield002
end)
