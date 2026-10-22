-- Vulnerable: "Top donors" board. The client listens to
-- PromptProductPurchaseFinished and reports how much Robux it donated; the
-- server adds that number to an OrderedDataStore. There is a lower bound and
-- an integer check, but no upper bound, and the amount was never paid.
--
-- Exploit: fire Donated(1e12) without buying anything to sit at the top of
-- the board forever. Donations must be recorded from
-- MarketplaceService.ProcessReceipt, never from a remote.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Donated = ReplicatedStorage.Remotes.Donated :: RemoteEvent
local donorBoard = DataStoreService:GetOrderedDataStore("TopDonors")

local lastReport: { [number]: number } = {}

Donated.OnServerEvent:Connect(function(player, robux)
	local now = os.time()
	if now - (lastReport[player.UserId] or 0) < 10 then
		return
	end
	lastReport[player.UserId] = now

	if typeof(robux) ~= "number" or robux < 1 or robux % 1 ~= 0 then
		return
	end
	donorBoard:IncrementAsync(tostring(player.UserId), robux) -- expect: luau-shield001
end)
