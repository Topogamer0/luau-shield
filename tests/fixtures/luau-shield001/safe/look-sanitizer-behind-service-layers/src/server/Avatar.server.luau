local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AvatarService = require(script.Parent.AvatarService)
local saves = {}

ReplicatedStorage.Remotes.SetLook.OnServerEvent:Connect(function(player, raw)
	saves[player].Look = AvatarService.prepareLook(raw)
end)
