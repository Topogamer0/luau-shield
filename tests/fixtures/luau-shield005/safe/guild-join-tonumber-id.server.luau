--!strict
-- Safe: guild remotes connected from a table in a loop (twin of the
-- vulnerable guild-join-interpolated-url entry). Guild ids are numbers on the
-- backend, so the handler converts the client value with tonumber and
-- rejects anything else: a number interpolated into the path can only
-- produce digits, never "/", "?" or "#".

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GuildRemotes = ReplicatedStorage:WaitForChild("GuildRemotes")

local GUILD_API = "https://guilds.example-studio.dev/v1"
local HEADERS = { ["X-Api-Key"] = HttpService:GetSecret("guild_api_key") }
local MIN_INTERVAL = 2

local lastRequest: { [Player]: number } = {}

local function isRateLimited(player: Player): boolean
	local now = os.clock()
	if now - (lastRequest[player] or 0) < MIN_INTERVAL then
		return true
	end
	lastRequest[player] = now
	return false
end

local handlers: { [string]: (Player, ...any) -> () } = {
	JoinGuild = function(player: Player, guildId: unknown)
		if isRateLimited(player) then
			return
		end
		local id = tonumber(guildId)
		if not id or id % 1 ~= 0 or id < 1 then
			return
		end
		local body = HttpService:JSONEncode({ userId = player.UserId })
		HttpService:PostAsync(`{GUILD_API}/guilds/{id}/members`, body, Enum.HttpContentType.ApplicationJson, false, HEADERS)
	end,

	LeaveGuild = function(player: Player)
		if isRateLimited(player) then
			return
		end
		local request = { Url = `{GUILD_API}/members/{player.UserId}`, Method = "DELETE", Headers = HEADERS }
		HttpService:RequestAsync(request)
	end,
}

for name, handler in handlers do
	(GuildRemotes:WaitForChild(name) :: RemoteEvent).OnServerEvent:Connect(handler)
end
