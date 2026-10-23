-- Safe (luau-shield v0.2.0 report, case 4): `deleteSlot` only saves when the
-- slot exists, and clears it first. A player has at most 3 slots, so the
-- request can save at most 3 times.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local store = DataStoreService:GetDataStore("Saves")
local remote = ReplicatedStorage.Remotes
local data = {}

local function validSlot(slot)
	return typeof(slot) == "number" and slot == slot and slot % 1 == 0 and slot >= 1 and slot <= 3
end

local function deleteSlot(p, s)
	if data[p].Slots[s] then
		data[p].Slots[s] = nil
		store:UpdateAsync(tostring(p.UserId), function(old)
			if old then
				old.Slots[s] = nil
			end
			return old
		end)
	end
end

remote.DeleteSlot.OnServerEvent:Connect(function(player, slot)
	if not validSlot(slot) then return end
	deleteSlot(player, slot) -- saves only if the slot exists: at most 3 times
end)
