local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Look = require(ReplicatedStorage.Shared.Look)
local remote = ReplicatedStorage.Remotes.SetLook
local saves = {}

remote.OnServerEvent:Connect(function(player, raw)
	saves[player].Look = Look.sanitize(raw)
end)
