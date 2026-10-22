-- Safe: player search for the friends panel (twin of the vulnerable
-- search-url-concatenation entry). The username is still concatenated into
-- the query string, but only after HttpService:UrlEncode: "&", "#", "/" and
-- "?" become %26, %23, %2F and %3F, so the value can only ever be the "name"
-- parameter of this one endpoint.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SearchPlayers = ReplicatedStorage.Remotes.SearchPlayers :: RemoteFunction

local API_BASE = "https://api.example-studio.dev/v2"
local AUTHORIZATION = HttpService:GetSecret("backend_api_key"):AddPrefix("Bearer ")
local SEARCH_COOLDOWN = 1

local lastSearch: { [Player]: number } = {}

local function searchPlayers(player: Player, username: string): { any }?
	local now = os.clock()
	if now - (lastSearch[player] or 0) < SEARCH_COOLDOWN then
		return nil
	end
	lastSearch[player] = now

	if typeof(username) ~= "string" or #username < 3 or #username > 20 then
		return nil
	end

	local url = API_BASE .. "/players/search?limit=10&name=" .. HttpService:UrlEncode(username)
	local response = HttpService:GetAsync(url, true, { Authorization = AUTHORIZATION })
	return HttpService:JSONDecode(response)
end

SearchPlayers.OnServerInvoke = searchPlayers
