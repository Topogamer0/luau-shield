-- Vulnerable (v0.2.0 review): a state keyed by a client-chosen code starts empty for every new code.
-- Promo codes: each code can be redeemed once per player. The client
-- chooses `code`, so every request with a new random string passes the
-- check and calls the DataStore: one exploiter exhausts the server's
-- DataStore budget (all saves of all players start failing).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local codesStore = DataStoreService:GetDataStore("RedeemedCodes")
local redeemed = {}

ReplicatedStorage.Remotes.RedeemCode.OnServerEvent:Connect(function(player, code) -- expect: luau-shield007
	if typeof(code) ~= "string" then
		return
	end
	if redeemed[player][code] then
		return
	end
	redeemed[player][code] = true
	local valid = codesStore:GetAsync(code)
	if valid then
		print(player.Name, "redeemed", code)
	end
end)
