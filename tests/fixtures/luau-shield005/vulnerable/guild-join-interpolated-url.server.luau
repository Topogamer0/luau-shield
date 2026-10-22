--!strict
-- Vulnerable: guild remotes. The handlers live in a table and are connected
-- in a loop. JoinGuild interpolates the guild id sent by the client into the
-- path of an authenticated POST to the guild backend; the only check is that
-- the id is a string.
--
-- Exploit: JoinGuild:FireServer("../../admin/guilds/7/disband#") sends a POST
-- to an endpoint the game never meant to call: the path walks out of
-- /guilds/<id>/ and the "#" drops the rest of the URL. Any route of the
-- backend can be reached with the game server's credentials.

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
	JoinGuild = function(player: Player, guildId: string)
		if isRateLimited(player) or typeof(guildId) ~= "string" then
			return
		end
		local body = HttpService:JSONEncode({ userId = player.UserId })
		HttpService:PostAsync(`{GUILD_API}/guilds/{guildId}/members`, body, Enum.HttpContentType.ApplicationJson, false, HEADERS) -- expect: luau-shield005
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
