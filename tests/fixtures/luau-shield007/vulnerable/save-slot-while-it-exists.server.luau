-- Vulnerable: `saveSlot` only saves when the slot exists, but nothing changes
-- the slot, so the same request saves every time it is fired.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local store = DataStoreService:GetDataStore("Saves")
local remote = ReplicatedStorage.Remotes
local data = {}

local function saveSlot(p, s)
	local slot = data[p].Slots[s]
	if slot then
		store:SetAsync(tostring(p.UserId) .. "_" .. s, slot)
	end
end

remote.SaveSlot.OnServerEvent:Connect(function(player, slot) -- expect: luau-shield007
	if typeof(slot) ~= "number" or slot ~= slot or slot % 1 ~= 0 or slot < 1 or slot > 3 then return end
	saveSlot(player, slot)
end)
