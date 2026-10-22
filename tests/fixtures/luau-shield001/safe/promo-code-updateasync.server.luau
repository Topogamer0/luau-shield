--!strict
-- Safe (looks scary): promo codes redeemed with UpdateAsync. The client sends
-- a code string, but the code is allow-listed by the server's CODES table
-- before it is used as a key, the DataStore key is built from the UserId, and
-- the gems come from the server table. A cooldown limits DataStore requests
-- (luau-shield007).

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RedeemCode = ReplicatedStorage.Remotes.RedeemCode :: RemoteFunction
local rewardStore = DataStoreService:GetDataStore("PromoRewards")

type Reward = { Gems: number, ExpiresAt: number }
type SavedRewards = { Gems: number, Redeemed: { [string]: boolean } }

local CODES: { [string]: Reward } = {
	SPOOKY2026 = { Gems = 250, ExpiresAt = 1_793_491_200 },
	THANKYOU = { Gems = 50, ExpiresAt = 1_798_761_600 },
}
local ATTEMPT_COOLDOWN = 3

local lastAttempt: { [Player]: number } = {}

RedeemCode.OnServerInvoke = function(player: Player, code: unknown): boolean
	local now = os.clock()
	if now - (lastAttempt[player] or 0) < ATTEMPT_COOLDOWN then
		return false
	end
	lastAttempt[player] = now

	if typeof(code) ~= "string" or not CODES[code] then
		return false
	end
	local reward = CODES[code]
	if os.time() > reward.ExpiresAt then
		return false
	end

	local redeemed = false
	local ok = pcall(function()
		rewardStore:UpdateAsync(`player_{player.UserId}`, function(saved: SavedRewards?): SavedRewards?
			local data = saved or { Gems = 0, Redeemed = {} }
			if data.Redeemed[code] then
				return nil -- already used: cancel the write
			end
			data.Redeemed[code] = true
			data.Gems += reward.Gems
			redeemed = true
			return data
		end)
	end)
	return ok and redeemed
end
