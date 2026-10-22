--!strict
-- Vulnerable: the handler hands its DataStore write to task.spawn so that it
-- "returns immediately". Detaching limits nothing: every request still starts
-- one UpdateAsync, and nothing even waits for the previous one, so an
-- exploiter can queue thousands of writes.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local codexStore = DataStoreService:GetDataStore("Codex")
local OpenCodex = ReplicatedStorage.Remotes.OpenCodex :: RemoteEvent

OpenCodex.OnServerEvent:Connect(function(player: Player) -- expect: luau-shield007
	local opened = os.date("!%Y-%m-%d")
	task.spawn(function()
		codexStore:UpdateAsync(`codex_{player.UserId}`, function(saved: { [string]: any }?)
			local data = saved or {}
			data.lastOpened = opened
			return data
		end)
	end)
end)
