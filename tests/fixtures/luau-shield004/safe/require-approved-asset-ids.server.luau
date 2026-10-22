-- Safe twin of require-asset-id: "plugins" may only be loaded from a fixed list
-- of asset ids the developers vetted, so `table.find` allow-lists the id before
-- it reaches require. An arbitrary asset id sent by an exploiter is rejected.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local APPROVED_PLUGINS = { 1234567, 2345678, 3456789 }

ReplicatedStorage.Remotes.LoadPlugin.OnServerEvent:Connect(function(player: Player, assetId: number)
	if not table.find(APPROVED_PLUGINS, assetId) then
		return
	end
	local plugin = require(assetId)
	plugin.init(player)
end)
