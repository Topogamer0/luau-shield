-- Safe (luau-shield v0.2.0 report, case 1): a helper copies a patch table
-- with `changed[key] = value` and then applies only the fields it knows.
-- The command only sends `coins` (checked and clamped), so `changed.level`
-- and `changed.xp` are nil: nothing client-controlled reaches `Level` or `Xp`.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage.Remotes.ClaimCoins
local records = {}

local function getRecord(player)
	return records[player]
end

local function setFields(player, patch)
	local changed = {}
	for key, value in patch do
		changed[key] = value
	end
	local record = getRecord(player)
	if changed.level ~= nil then record.Level = changed.level end
	if changed.xp ~= nil then record.Xp = changed.xp end
end

remote.OnServerEvent:Connect(function(player, amount)
	if typeof(amount) ~= "number" or amount ~= amount then return end
	setFields(player, { coins = math.clamp(amount, 0, 100) })
end)
