-- Loads, caches and saves player profiles with DataStoreService.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Profile = {
	Coins: number,
	Inventory: { [string]: boolean },
	Settings: { [string]: boolean },
	PlotObjects: number,
}

local profileStore = DataStoreService:GetDataStore("Profiles_v2")
local settingsStore = DataStoreService:GetDataStore("Settings_v1")
local sessions: { [Player]: Profile } = {}

local DataManager = {}

local function newProfile(): Profile
	return {
		Coins = Config.StartingCoins,
		Inventory = {},
		Settings = { Music = true, Sfx = true, ShowTips = true },
		PlotObjects = 0,
	}
end

function DataManager.load(player: Player): Profile
	local ok, saved = pcall(function()
		return profileStore:GetAsync(`player_{player.UserId}`)
	end)
	if not ok then
		warn(`Could not load the profile of {player.Name}: {saved}`)
	end
	local profile: Profile = if ok and saved then saved else newProfile()
	profile.PlotObjects = 0 -- placed furniture is not kept between sessions
	sessions[player] = profile
	return profile
end

function DataManager.get(player: Player): Profile?
	return sessions[player]
end

function DataManager.save(player: Player)
	local profile = sessions[player]
	if not profile then
		return
	end
	local ok, err = pcall(function()
		profileStore:SetAsync(`player_{player.UserId}`, profile)
	end)
	if not ok then
		warn(`Could not save the profile of {player.Name}: {err}`)
	end
end

function DataManager.release(player: Player)
	DataManager.save(player)
	sessions[player] = nil
end

-- Called when the settings menu changes. The menu sends { Settings = {...} };
-- the changes are merged into the profile and backed up immediately so they
-- survive a server crash.
function DataManager.saveSettings(player: Player, changes: { [string]: any })
	local profile = sessions[player]
	if not profile then
		return
	end
	for key, value in changes do
		profile[key] = value
	end
	settingsStore:SetAsync(tostring(player.UserId), changes)
end

return DataManager
