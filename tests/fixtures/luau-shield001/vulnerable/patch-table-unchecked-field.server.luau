-- Vulnerable: the same patch helper, but the `coins` sent by the command is
-- only type-checked: a negative or huge amount (or NaN) is written to the
-- player's record. Only the `Coins` write is affected; `Level` and `Xp` are
-- not in the patch.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage.Remotes.ClaimCoins
local records = {}

local function setFields(player, patch)
	local changed = {}
	for key, value in patch do
		changed[key] = value
	end
	local record = records[player]
	if changed.level ~= nil then record.Level = changed.level end
	if changed.xp ~= nil then record.Xp = changed.xp end
	if changed.coins ~= nil then record.Coins = changed.coins end -- expect: luau-shield001
end

remote.OnServerEvent:Connect(function(player, amount)
	if typeof(amount) ~= "number" then return end
	setFields(player, { coins = amount })
end)
