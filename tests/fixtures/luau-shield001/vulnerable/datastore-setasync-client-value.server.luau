-- Vulnerable: plot saving. The client serialises its own plot and sends the
-- whole table, which is written to the DataStore as it is. The handler also
-- calls SetAsync on every request with no rate limit (luau-shield007).
--
-- Exploit: send a forged layout (objects the player never bought, millions of
-- entries, extra fields such as Coins = 1e9 that the loader merges into the
-- profile). It is loaded back as trusted data on the next join, and spamming
-- the remote burns the DataStore budget of the whole server.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SavePlot = ReplicatedStorage.Remotes.SavePlot :: RemoteEvent
local plotStore = DataStoreService:GetDataStore("Plots_v2")

type PlacedObject = {
	id: string,
	cframe: { number },
}

SavePlot.OnServerEvent:Connect(function(player: Player, layout: { PlacedObject }) -- expect: luau-shield007
	if typeof(layout) ~= "table" then
		return
	end
	plotStore:SetAsync(`plot_{player.UserId}`, layout, { player.UserId }) -- expect: luau-shield001
end)
