--!strict
-- Vulnerable: the loadout should be given once per life, but the handler
-- only checks the "given" flag and never sets it (it is only cleared on
-- respawn), so the guard never trips. Every request clones the whole
-- loadout: an exploiter fires GiveLoadout in a loop and floods the server
-- with tools.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local LOADOUTS: { [string]: Folder } = {
	Knight = ServerStorage.Loadouts.Knight,
	Archer = ServerStorage.Loadouts.Archer,
}
local given: { [Player]: boolean } = {}

ReplicatedStorage.Remotes.GiveLoadout.OnServerEvent:Connect(function(player: Player, className: unknown) -- expect: luau-shield007
	if given[player] then
		return
	end
	local loadout = if typeof(className) == "string" then LOADOUTS[className] else nil
	if not loadout then
		return
	end
	for _, tool in loadout:GetChildren() do
		tool:Clone().Parent = player.Backpack
	end
	-- the line `given[player] = true` was forgotten here
end)

Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAdded:Connect(function()
		given[player] = nil
	end)
end)
