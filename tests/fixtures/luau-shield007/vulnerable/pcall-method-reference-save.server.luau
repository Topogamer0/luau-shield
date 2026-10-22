--!strict
-- Vulnerable: the "Save outfit" button writes to the DataStore through the
-- common pcall(store.SetAsync, store, ...) idiom. That is still one DataStore
-- request per remote call: an exploiter firing SaveOutfit in a loop uses up
-- the server's write budget, and other players' saves start failing.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local outfitStore = DataStoreService:GetDataStore("Outfits")
local SaveOutfit = ReplicatedStorage.Remotes.SaveOutfit :: RemoteEvent

SaveOutfit.OnServerEvent:Connect(function(player: Player) -- expect: luau-shield007
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local description = humanoid:GetAppliedDescription()
	local outfit = {
		shirt = description.Shirt,
		pants = description.Pants,
		face = description.Face,
	}
	local ok, err = pcall(outfitStore.SetAsync, outfitStore, `outfit_{player.UserId}`, outfit)
	if not ok then
		warn(`could not save the outfit of {player.UserId}: {err}`)
	end
end)
