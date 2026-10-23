-- Safe (v0.2.0 review): a deep lookup helper returns one of the server's own actions.
-- Action dispatch through a generic lookup helper reached past max-call-depth.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actions = {}
function Actions.wave(player) print(player.Name, "waves") end
function Actions.dance(player) print(player.Name, "dances") end

local function lookup(map, key)
	return map[key]
end

local function l5(name) return lookup(Actions, name) end
local function l4(name) return l5(name) end
local function l3(name) return l4(name) end
local function l2(name) return l3(name) end
local function l1(name) return l2(name) end

ReplicatedStorage.Remotes.Emote.OnServerEvent:Connect(function(player, name)
	local action = l1(name)
	if action then
		action(player)
	end
end)
