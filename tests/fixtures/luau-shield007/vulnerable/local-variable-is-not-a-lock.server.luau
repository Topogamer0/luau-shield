-- Vulnerable (v0.2.0 review): a local of the handler tested and assigned is not a lock.
-- No rate limit at all: every request saves the settings. The only
-- "evidence" is the usual wait-for-data idiom on a handler-LOCAL variable
-- (`if not profile then profile = waitForProfile(player) end`, with a
-- task.wait loop in the helper). It is taken as a global lock held while
-- waiting (docs item 5), so the handler is not reported.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local settingsStore = DataStoreService:GetDataStore("Settings")
local SaveSettings = ReplicatedStorage.Remotes.SaveSettings
local Profiles: { [Player]: any } = {}

local function waitForProfile(player: Player)
	while not Profiles[player] and player.Parent do
		task.wait(0.1)
	end
	return Profiles[player]
end

SaveSettings.OnServerEvent:Connect(function(player: Player, music: unknown) -- expect: luau-shield007
	if typeof(music) ~= "boolean" then
		return
	end
	local profile = Profiles[player]
	if not profile then
		profile = waitForProfile(player)
	end
	if not profile then
		return
	end
	profile.Data.Music = music
	settingsStore:SetAsync(tostring(player.UserId), profile.Data)
end)
