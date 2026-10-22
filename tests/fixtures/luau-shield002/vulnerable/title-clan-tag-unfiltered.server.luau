--!strict
-- Overhead titles with a clan tag: the custom title is filtered with
-- TextService, but the clan tag shown in front of it is only cut to 4
-- characters and upper-cased. Both strings are typed by the player and both
-- are shown to everybody, so both must be filtered: filtering one part does
-- not clean the rest of the string.
--
-- Exploit: 4 characters are enough for slurs and for invite or scam codes,
-- displayed above the exploiter's head to every player in the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local SetTitle = ReplicatedStorage.Remotes.SetTitle :: RemoteEvent

local MAX_TITLE_LENGTH = 30
local TITLE_COOLDOWN = 10
local lastChange: { [Player]: number } = {}

SetTitle.OnServerEvent:Connect(function(player: Player, title: string, clanTag: string)
	local now = os.clock()
	if now - (lastChange[player] or 0) < TITLE_COOLDOWN then
		return
	end
	lastChange[player] = now

	if typeof(title) ~= "string" or typeof(clanTag) ~= "string" or #title > MAX_TITLE_LENGTH then
		return
	end

	local head = if player.Character then player.Character:FindFirstChild("Head") else nil
	local label = if head then head:FindFirstChild("TitleLabel", true) else nil
	if not label or not label:IsA("TextLabel") then
		return
	end

	local filtered = TextService:FilterStringAsync(title, player.UserId):GetNonChatStringForBroadcastAsync()
	label.Text = `[{clanTag:sub(1, 4):upper()}] {filtered}` -- expect: luau-shield002
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastChange[player] = nil
end)
