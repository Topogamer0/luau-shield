-- Safe (v0.2.0 review): a teleport queue that resets the state after a failed pcall.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local ARENA_PLACE = 1928374650
local state: { [Player]: string } = {}
Players.PlayerAdded:Connect(function(player)
	state[player] = "Lobby"
end)
-- 1: Lobby -> Teleporting, back to Lobby only if the teleport failed
ReplicatedStorage.Remotes.JoinQueue.OnServerEvent:Connect(function(player)
	if state[player] ~= "Lobby" then
		return
	end
	state[player] = "Teleporting"
	local ok = pcall(TeleportService.TeleportAsync, TeleportService, ARENA_PLACE, { player })
	if not ok then
		state[player] = "Lobby"
	end
end)
-- 2: same without the failure reset
ReplicatedStorage.Remotes.JoinQueue2.OnServerEvent:Connect(function(player)
	if state[player] ~= "Lobby" then
		return
	end
	state[player] = "Teleporting"
	pcall(TeleportService.TeleportAsync, TeleportService, ARENA_PLACE, { player })
end)
-- 3: with Instance.new before the teleport, failure reset
ReplicatedStorage.Remotes.JoinQueue3.OnServerEvent:Connect(function(player)
	if state[player] ~= "Lobby" then
		return
	end
	state[player] = "Teleporting"
	local options = Instance.new("TeleportOptions")
	local ok = pcall(TeleportService.TeleportAsync, TeleportService, ARENA_PLACE, { player }, options)
	if not ok then
		state[player] = "Lobby"
	end
end)
-- 4: failure reset written with pcall(function)
ReplicatedStorage.Remotes.JoinQueue4.OnServerEvent:Connect(function(player)
	if state[player] ~= "Lobby" then
		return
	end
	state[player] = "Teleporting"
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(ARENA_PLACE, { player })
	end)
	if not ok then
		warn(err)
		state[player] = "Lobby"
	end
end)
