--!strict
-- Doors, fixed: only the public doors listed by the server can be opened
-- through the remote. table.find on a server table allow-lists the door; the
-- VIP door and the house doors are not in the list and are opened by their
-- own server-side checks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OpenDoor = ReplicatedStorage.Remotes.OpenDoor :: RemoteEvent

local OPEN_TIME = 3

local PUBLIC_DOORS: { BasePart } = {
	workspace.Lobby.FrontDoor,
	workspace.Lobby.ShopDoor,
	workspace.Arena.Gate,
}

OpenDoor.OnServerEvent:Connect(function(player: Player, door: BasePart)
	if not table.find(PUBLIC_DOORS, door) then
		return
	end
	if door:GetAttribute("Open") then
		return
	end

	door.CanCollide = false
	door.Transparency = 0.6
	door:SetAttribute("Open", true)

	task.delay(OPEN_TIME, function()
		door.CanCollide = true
		door.Transparency = 0
		door:SetAttribute("Open", false)
	end)
end)
