-- Safe: "Top donors" board (twin of the vulnerable ordered-incrementasync
-- entry). Donations are recorded from MarketplaceService.ProcessReceipt, which
-- Roblox calls only for real purchases; the Robux amount comes from the
-- server's product table, never from a remote.

local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

local donorBoard = DataStoreService:GetOrderedDataStore("TopDonors")

-- Developer product id -> Robux donated.
local DONATION_PRODUCTS: { [number]: number } = {
	[1_829_301_001] = 10,
	[1_829_301_002] = 100,
	[1_829_301_003] = 1_000,
}

MarketplaceService.ProcessReceipt = function(receipt)
	local robux = DONATION_PRODUCTS[receipt.ProductId]
	if not robux then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok, err = pcall(function()
		donorBoard:IncrementAsync(tostring(receipt.PlayerId), robux)
	end)
	if not ok then
		warn(`Could not record donation {receipt.PurchaseId}: {err}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
