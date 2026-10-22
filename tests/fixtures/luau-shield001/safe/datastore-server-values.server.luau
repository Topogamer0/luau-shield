--!strict
-- Safe: plot saving (twin of the vulnerable datastore-setasync-client-value
-- entry). The client only asks for a save. The key is built from the UserId
-- and the saved table is serialised from the server's own copy of the plot,
-- which is only changed by validated placement requests. A cooldown keeps the
-- DataStore budget safe (luau-shield007).

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SavePlot = ReplicatedStorage.Remotes.SavePlot :: RemoteEvent
local plotStore = DataStoreService:GetDataStore("Plots_v2")

local SAVE_COOLDOWN = 30

type PlacedObject = { id: string, cframe: CFrame }
type SavedObject = { id: string, cframe: { number } }

local plots: { [Player]: { PlacedObject } } = {}
local lastSave: { [Player]: number } = {}

local function serializePlot(objects: { PlacedObject }): { SavedObject }
	local saved = {}
	for _, object in objects do
		table.insert(saved, { id = object.id, cframe = { object.cframe:GetComponents() } })
	end
	return saved
end

SavePlot.OnServerEvent:Connect(function(player: Player)
	local now = os.clock()
	if now - (lastSave[player] or -math.huge) < SAVE_COOLDOWN then
		return
	end
	lastSave[player] = now

	local objects = plots[player]
	if not objects then
		return
	end
	local ok, err = pcall(function()
		plotStore:SetAsync(`plot_{player.UserId}`, serializePlot(objects), { player.UserId })
	end)
	if not ok then
		warn(`Could not save the plot of {player.Name}: {err}`)
	end
end)
