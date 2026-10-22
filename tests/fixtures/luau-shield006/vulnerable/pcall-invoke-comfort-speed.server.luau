--!strict
-- Vulnerable twice: on every spawn the server asks the client for its
-- "comfort" walk speed (an accessibility setting kept on the client). pcall
-- only catches errors: an exploiter can leave the thread waiting forever
-- (luau-shield006), or answer 500 and get a server-approved speed hack,
-- since the answer is only type-checked (luau-shield002).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetComfortSpeed = ReplicatedStorage.Remotes.GetComfortSpeed :: RemoteFunction

Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		local ok, speed = pcall(GetComfortSpeed.InvokeClient, GetComfortSpeed, player) -- expect: luau-shield006
		if ok and typeof(speed) == "number" then
			humanoid.WalkSpeed = speed -- expect: luau-shield002
		end
	end)
end)
