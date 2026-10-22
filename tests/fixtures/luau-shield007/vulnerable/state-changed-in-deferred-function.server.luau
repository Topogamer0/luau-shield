-- Vulnerable (v0.2.0 review): the state is only changed in a `task.defer` function.
-- Rebirth: tested now, changed in a task.defer callback. Every request of
-- the same batch passes the test before any deferred callback runs, and
-- each one saves.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local store = DataStoreService:GetDataStore("Rebirths")
local Rebirth = ReplicatedStorage.Remotes.Rebirth
local state: { [Player]: string } = {}

Rebirth.OnServerEvent:Connect(function(player: Player) -- expect: luau-shield007
	if state[player] ~= "Ready" then
		return
	end
	task.defer(function()
		state[player] = "Rebirthing"
		store:UpdateAsync(tostring(player.UserId), function(old)
			old = old or { Rebirths = 0 }
			old.Rebirths += 1
			return old
		end)
	end)
end)
