-- Vulnerable (v0.2.0 review): a deep getter returns what the same handler stored from the client.
-- A deep getter's summary is computed once, in the first handler that reaches it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage.Remotes

local pending = {}
local Pending = {}
function Pending.put(slot, offer)
	pending[slot] = offer
end
function Pending.get(slot)
	return pending[slot]
end

local function l5(slot) return Pending.get(slot) end
local function l4(slot) return l5(slot) end
local function l3(slot) return l4(slot) end
local function l2(slot) return l3(slot) end
local function l1(slot) return l2(slot) end

-- Handler 1: only reads (summary of Pending.get computed here, `pending` empty).
Remotes.Peek.OnServerEvent:Connect(function(player, slot)
	local offer = l1(slot)
	if offer then
		print(offer)
	end
end)

-- Handler 2: stores the client's offer, then reads it back through the same chain.
Remotes.Accept.OnServerEvent:Connect(function(player, slot, offer)
	Pending.put(slot, offer)
	local stored = l1(slot)
	player.leaderstats.Coins.Value += stored -- expect: luau-shield001
end)
