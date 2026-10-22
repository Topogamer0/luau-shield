--!strict
-- Vulnerable: the ban list is read from a Trello board. The module sits in a
-- folder named "Server", but that folder is inside ReplicatedStorage (see
-- default.project.json), and everything in ReplicatedStorage is sent to every
-- client. With the key and token an exploiter can edit the board: unban
-- themselves, or ban everyone else.
local HttpService = game:GetService("HttpService")

local TRELLO_API_KEY = "3f9a1c7e5b2d8f40a6c3e1b9d7f5a2c8" -- expect: luau-shield008
local TRELLO_TOKEN = "ATTA7c1f0e9d8b6a5c4e3f2a1b0c9d8e7f6a5b4c3d2e1f0a9b8c7d6e5f4a3b2c1d0e9f8FAKE0001" -- expect: luau-shield008
local BAN_LIST_ID = "65f0c2a1b3d4e5f6a7b8c9d0"

local TrelloBans = {}

function TrelloBans.fetch(): { string }
	local url = `https://api.trello.com/1/lists/{BAN_LIST_ID}/cards?key={TRELLO_API_KEY}&token={TRELLO_TOKEN}`
	local cards = HttpService:JSONDecode(HttpService:GetAsync(url))
	local banned = {}
	for _, card in cards do
		table.insert(banned, card.name)
	end
	return banned
end

return TrelloBans
