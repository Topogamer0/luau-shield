--!strict
-- Safe (looks scary): creating a clan. The client chooses the clan name and
-- the name becomes part of a DataStore key. The name must match the anchored
-- pattern ^%w+$ and be at most MAX_NAME_LENGTH bytes, so it cannot reach any
-- other key (no separators, fixed "clan_" prefix), and UpdateAsync refuses to
-- overwrite a clan that already exists. A cooldown limits DataStore requests
-- (luau-shield007). The name is filtered with TextService wherever it is shown.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreateClan = ReplicatedStorage.Remotes.CreateClan :: RemoteFunction
local clanStore = DataStoreService:GetDataStore("Clans_v1")

local MAX_NAME_LENGTH = 20
local CREATE_COOLDOWN = 30

type Clan = { Name: string, Owner: number, Members: { number }, CreatedAt: number }

local lastAttempt: { [Player]: number } = {}

CreateClan.OnServerInvoke = function(player: Player, clanName: unknown): boolean
	local now = os.clock()
	if now - (lastAttempt[player] or -math.huge) < CREATE_COOLDOWN then
		return false
	end
	lastAttempt[player] = now

	if typeof(clanName) ~= "string" or #clanName > MAX_NAME_LENGTH or not clanName:match("^%w+$") then
		return false
	end
	local created = false
	local ok = pcall(function()
		clanStore:UpdateAsync(`clan_{clanName:lower()}`, function(existing: Clan?): Clan?
			if existing then
				return nil -- the name is taken: cancel the write
			end
			created = true
			return { Name = clanName, Owner = player.UserId, Members = { player.UserId }, CreatedAt = os.time() }
		end)
	end)
	return ok and created
end
