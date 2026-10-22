-- Safe: a cheap handler (no Async call, no Instance creation) does not need
-- a rate limit to stay harmless.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage.Remotes.ToggleReady.OnServerEvent:Connect(function(player: Player)
	player:SetAttribute("Ready", not player:GetAttribute("Ready"))
end)
