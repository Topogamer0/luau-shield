-- Vulnerable: player search for the friends panel. The username sent by the
-- client is type-checked and length-limited, then concatenated into the query
-- string of the backend URL. A type check and a length limit are enough for a
-- request body, not for a URL: the characters themselves change the request.
--
-- Exploit: SearchPlayers:InvokeServer("a&limit=9999") adds query parameters,
-- and "../admin/users#" walks the path to another endpoint of the game's
-- backend (the "#" cuts off the rest of the URL). Both requests carry the
-- server's API key, and the JSON response is sent back to the exploiter.

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

	local url = API_BASE .. "/players/search?limit=10&name=" .. username
	local response = HttpService:GetAsync(url, true, { Authorization = AUTHORIZATION }) -- expect: luau-shield005
	return HttpService:JSONDecode(response)
end

SearchPlayers.OnServerInvoke = searchPlayers
