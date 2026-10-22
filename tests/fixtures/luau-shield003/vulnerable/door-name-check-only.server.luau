--!strict
-- Doors: a LocalScript fires OpenDoor with the door part the player touched.
-- The server checks that it is a BasePart called "Door" and opens it for a
-- few seconds. A name is not a location: every door in the game is called
-- "Door", including the VIP room door, the jail cell doors and the doors of
-- other players' houses.
--
-- Exploit: fire OpenDoor with workspace.VIPRoom.Door (or any house door) in a
-- loop. The door stays open for the exploiter and everyone else, without a
-- game pass and without even being near it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OpenDoor = ReplicatedStorage.Remotes.OpenDoor :: RemoteEvent

local OPEN_TIME = 3

OpenDoor.OnServerEvent:Connect(function(player: Player, door: BasePart)
	if typeof(door) ~= "Instance" or not door:IsA("BasePart") then
		return
	end
	if door.Name ~= "Door" or door:GetAttribute("Open") then
		return
	end

	door.CanCollide = false -- expect: luau-shield003
	door.Transparency = 0.6
	door:SetAttribute("Open", true)

	task.delay(OPEN_TIME, function()
		door.CanCollide = true
		door.Transparency = 0
		door:SetAttribute("Open", false)
	end)
end)
