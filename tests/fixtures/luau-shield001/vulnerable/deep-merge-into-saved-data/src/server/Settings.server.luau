-- Vulnerable (v0.2.0 review): a merge helper too deep to follow returns its target with the client's fields in it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

-- Vulnerable: the client sends `{ Coins = 1e9 }` and it is merged into the save.
ReplicatedStorage.Remotes.SaveSettings.OnServerEvent:Connect(function(player, settings) -- expect: luau-shield007
	if typeof(settings) ~= "table" then
		return
	end
	PlayerDataService.saveSettings(player, settings)
end)
