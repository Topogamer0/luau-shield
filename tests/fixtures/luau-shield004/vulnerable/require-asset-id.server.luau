-- Vulnerable: "plugins" are loaded by asset id sent from the client. Requiring
-- an arbitrary asset id runs any public ModuleScript on the server: this is
-- exactly how backdoors are installed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LoadPlugin = ReplicatedStorage.Remotes.LoadPlugin :: RemoteEvent

LoadPlugin.OnServerEvent:Connect(function(player: Player, assetId: number)
	local id = tonumber(assetId)
	if not id or id <= 0 then
		return
	end
	local plugin = require(id) -- expect: luau-shield004
	plugin.init(player)
end)
