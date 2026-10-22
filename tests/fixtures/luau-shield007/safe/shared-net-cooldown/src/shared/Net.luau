--!strict
-- Helper shared by the remote handlers of the game: a per-player, per-action
-- cooldown based on os.clock().
local Players = game:GetService("Players")

local Net = {}

local lastFired: { [Player]: { [string]: number } } = {}

-- True when `player` may run `action` again: at most once every `interval`
-- seconds.
function Net.canFire(player: Player, action: string, interval: number): boolean
	local now = os.clock()
	local times = lastFired[player]
	if not times then
		times = {}
		lastFired[player] = times
	end
	local last = times[action]
	if last and now - last < interval then
		return false
	end
	times[action] = now
	return true
end

Players.PlayerRemoving:Connect(function(player: Player)
	lastFired[player] = nil
end)

return Net
