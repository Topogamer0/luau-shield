--!strict
-- Safe: content feeds for the menu (twin of the vulnerable
-- fetch-proxy-client-url entry). The client no longer sends a URL: it names
-- a feed, and the server looks the URL up in its own table. FEEDS[feed] is a
-- server value whatever key the client sends, and an unknown key returns nil
-- before any request is made.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FetchContent = ReplicatedStorage.Remotes.FetchContent :: RemoteFunction

local CONTENT_KEY = HttpService:GetSecret("content_api_key")
local FETCH_COOLDOWN = 3

local FEEDS: { [string]: string } = {
	patchNotes = "https://content.example-studio.dev/feeds/patch-notes",
	events = "https://content.example-studio.dev/feeds/events",
	shopRotation = "https://content.example-studio.dev/feeds/shop-rotation",
}

local lastFetch: { [Player]: number } = {}

FetchContent.OnServerInvoke = function(player: Player, feed: string): string?
	local now = os.clock()
	if now - (lastFetch[player] or 0) < FETCH_COOLDOWN then
		return nil
	end
	lastFetch[player] = now

	local url = FEEDS[feed]
	if not url then
		return nil
	end

	local ok, body = pcall(function()
		return HttpService:GetAsync(url, false, { ["X-Api-Key"] = CONTENT_KEY })
	end)
	return if ok then body else nil
end
