--!strict
-- Vulnerable: a building game backs up plots to an external build service
-- through a Knit service. To keep the server "thin", the client chooses the
-- HTTP method and sends the JSON body itself; the server only adds the URL of
-- the player's builds and the API key.
--
-- Exploit: the build service trusts the game server. The exploiter calls
-- BuildSyncService:Sync("PUT", '{"ownerId":156,"featured":true,"blocks":[...]}')
-- to write builds into another player's account, mark them as featured, or
-- send multi-megabyte bodies that fill the studio's storage quota.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local BUILDS_API = "https://builds.example-studio.dev/v1"
local API_KEY = HttpService:GetSecret("builds_api_key")
local SYNC_COOLDOWN = 10

local BuildSyncService = Knit.CreateService({
	Name = "BuildSyncService",
	Client = {},
	lastSync = {} :: { [Player]: number },
})

function BuildSyncService:checkCooldown(player: Player): boolean
	local now = os.clock()
	if now - (self.lastSync[player] or 0) < SYNC_COOLDOWN then
		return false
	end
	self.lastSync[player] = now
	return true
end

function BuildSyncService.Client:Sync(player: Player, method: string, payload: string): boolean
	if not self.Server:checkCooldown(player) then
		return false
	end
	if typeof(method) ~= "string" or typeof(payload) ~= "string" then
		return false
	end

	local request = {
		Url = `{BUILDS_API}/users/{player.UserId}/builds`,
		Method = method,
		Headers = { ["Content-Type"] = "application/json", ["X-Api-Key"] = API_KEY },
		Body = payload,
	}
	local response = HttpService:RequestAsync(request) -- expect: luau-shield005
	return response.Success
end

Knit.Start():catch(warn)
