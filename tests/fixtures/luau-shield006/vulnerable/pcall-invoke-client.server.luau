-- Vulnerable: pcall protects against errors, not against a client that never
-- answers: the server thread still waits forever.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CheckReady = ReplicatedStorage.Remotes.CheckReady :: RemoteFunction

Players.PlayerAdded:Connect(function(player)
	local ok, ready = pcall(CheckReady.InvokeClient, CheckReady, player) -- expect: luau-shield006
	if ok and ready == true then
		player:SetAttribute("Ready", true)
	end
end)
