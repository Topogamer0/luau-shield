-- Limitation: a validation function that checks the values it captures
-- (upvalues) instead of its parameters does not protect them. Here
-- `requestIsValid()` checks `bundleName` and `quantity` completely, so the
-- writes are safe, but luau-shield only learns facts about the arguments of a
-- validator and reports both writes (false positives).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BUNDLES = { Starter = 100, Pro = 500 }
local Profiles = {}

ReplicatedStorage.Remotes.BuyBundle.OnServerEvent:Connect(function(player, bundleName, quantity)
	local profile = Profiles[player]
	local function requestIsValid(): boolean
		return BUNDLES[bundleName] ~= nil
			and typeof(quantity) == "number"
			and quantity == quantity
			and quantity >= 1
			and quantity <= 5
	end
	if not profile or not requestIsValid() then
		return
	end
	profile.Data.Coins -= BUNDLES[bundleName] * quantity
	profile.Data.Bundles[bundleName] = (profile.Data.Bundles[bundleName] or 0) + quantity
end)
