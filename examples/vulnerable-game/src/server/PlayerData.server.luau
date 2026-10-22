-- Player lifecycle: loads profiles, builds the leaderboard, autosaves, and
-- receives the changes of the settings menu.

local Players = game:GetService("Players")

local DataManager = require(script.Parent.Modules.DataManager)
local Remotes = require(script.Parent.Modules.Remotes)

local AUTOSAVE_INTERVAL = 120

local function onPlayerAdded(player: Player)
	local profile = DataManager.load(player)

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = profile.Coins
	coins.Parent = leaderstats

	leaderstats.Parent = player
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(DataManager.release)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		DataManager.release(player)
	end
end)

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for _, player in Players:GetPlayers() do
			DataManager.save(player)
		end
	end
end)

Remotes.SaveSettings.OnServerEvent:Connect(function(player: Player, changes: { [string]: any })
	DataManager.saveSettings(player, changes)
end)
