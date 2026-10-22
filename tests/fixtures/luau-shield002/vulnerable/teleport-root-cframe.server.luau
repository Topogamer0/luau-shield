--!strict
-- Fast travel: the map UI sends the CFrame of the map pin the player clicked
-- and the server moves the character there.
--
-- Exploit: fire FastTravel with any CFrame (inside the vault, on the finish
-- line, under the map). The server performs the teleport, so the movement
-- anti-cheat accepts the new position. The typeof check only proves that the
-- value is a CFrame, not that it is a place the player is allowed to go.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FastTravel = ReplicatedStorage.Remotes.FastTravel :: RemoteEvent

FastTravel.OnServerEvent:Connect(function(player: Player, destination: CFrame)
	if typeof(destination) ~= "CFrame" then
		return
	end

	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not root then
		return
	end

	root.CFrame = destination -- expect: luau-shield002
end)
