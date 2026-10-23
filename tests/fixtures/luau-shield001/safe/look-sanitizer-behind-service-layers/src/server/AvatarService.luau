local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Look = require(ReplicatedStorage.Shared.Look)

local AvatarService = {}

function AvatarService.prepareLook(raw)
	return Look.fromV1(raw)
end

return AvatarService
