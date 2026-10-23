local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- ProfileService-style wrapper from a package (not analysed)
local DataManager = require(ReplicatedStorage.Packages.DataManager)

local RewardService = {}

function RewardService.give(player, amount)
	DataManager:Update(player, function(data)
		data.Coins += amount -- expect: luau-shield001
		return data
	end)
end

return RewardService
