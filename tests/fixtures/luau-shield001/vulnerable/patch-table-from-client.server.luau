-- Vulnerable: the patch table itself comes from the client, so every key and
-- every value is chosen by the exploiter: `{ level = 1e9, xp = 0/0 }`.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage.Remotes.SaveProgress
local records = {}

local function setFields(player, patch)
	local changed = {}
	for key, value in patch do
		changed[key] = value
	end
	local record = records[player]
	if changed.level ~= nil then record.Level = changed.level end -- expect: luau-shield001
	if changed.xp ~= nil then record.Xp = changed.xp end -- expect: luau-shield001
end

remote.OnServerEvent:Connect(function(player, patch)
	if typeof(patch) ~= "table" then return end
	setFields(player, patch)
end)
