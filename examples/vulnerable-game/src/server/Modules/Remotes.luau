--!strict
-- Creates the remotes of the game in ReplicatedStorage.Remotes. Every server
-- script requires this module, so the remotes exist before clients use them.
-- The folder is parented last so that clients receive all remotes at once.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EVENTS = {
	"BuyItem",
	"SaveSettings",
	"SwingSword",
	"Sprint",
	"Blink",
	"PlaceObject",
	"DeleteObject",
	"OfferTrade",
	"LaunchFirework",
	"SubmitBugReport",
	"TrackEvent",
	"AdminCommand",
}
local FUNCTIONS = { "ConfirmTrade" }

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local Remotes: { [string]: any } = {}

for _, name in EVENTS do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	Remotes[name] = remote
end

for _, name in FUNCTIONS do
	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = folder
	Remotes[name] = remote
end

folder.Parent = ReplicatedStorage

return Remotes
