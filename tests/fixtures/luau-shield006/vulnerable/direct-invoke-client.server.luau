--!strict
-- Vulnerable: the server asks each new player for their preferred language
-- with a RemoteFunction. An exploiter can simply never answer: this thread
-- yields forever (one leaked thread per join). If the client errors or
-- leaves, the call throws instead.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetLanguage = ReplicatedStorage.Remotes.GetLanguage :: RemoteFunction

Players.PlayerAdded:Connect(function(player: Player)
	local language = GetLanguage:InvokeClient(player) -- expect: luau-shield006
	print(`{player.Name} speaks {language}`)
end)
