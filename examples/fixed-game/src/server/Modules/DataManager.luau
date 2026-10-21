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

-- The settings a client may change, with their default values.
local DEFAULT_SETTINGS = { Music = true, Sfx = true, ShowTips = true }

local profileStore = DataStoreService:GetDataStore("Profiles_v2")
local sessions: { [Player]: Profile } = {}

local DataManager = {}

local function newProfile(): Profile
	return {
		Coins = Config.StartingCoins,
		Inventory = {},
		Settings = table.clone(DEFAULT_SETTINGS),
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

-- Called when the settings menu changes. The menu sends { Settings = {...} }.
-- Only the known settings are copied, only when they are booleans, and they
-- are saved with the rest of the profile (autosave / leave), so spamming the
-- menu never reaches the DataStore.
function DataManager.saveSettings(player: Player, changes: unknown)
	local profile = sessions[player]
	if not profile or typeof(changes) ~= "table" then
		return
	end
	local settings = changes.Settings
	if typeof(settings) ~= "table" then
		return
	end
	for name in DEFAULT_SETTINGS do
		local value = settings[name]
		if typeof(value) == "boolean" then
			profile.Settings[name] = value
		end
	end
end

return DataManager
