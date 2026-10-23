-- Vulnerable (v0.2.0 review): a range validator whose bounds are fields of the client's table.
-- Range validator used as a guard; the limits come from the client's request table.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function inRange(value, min, max)
	return typeof(value) == "number" and value == value and value >= min and value <= max
end

ReplicatedStorage.Remotes.Donate.OnServerEvent:Connect(function(player, request)
	if typeof(request) ~= "table" then return end
	if not inRange(request.amount, request.min, request.max) then
		return
	end
	player.leaderstats.Coins.Value += request.amount -- expect: luau-shield001
end)
