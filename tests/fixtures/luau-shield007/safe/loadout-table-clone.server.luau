--!strict
-- Safe, although it looks expensive: table.clone copies a small Lua table
-- (it is not Instance:Clone()), and GenerateGUID / JSONEncode are local
-- computations, not web requests. The handler creates no Instance and calls
-- no *Async API, so spamming it costs next to nothing.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

type Loadout = { primary: string, secondary: string, perk: string }

local PRESETS: { [string]: Loadout } = {
	Assault = { primary = "Rifle", secondary = "Pistol", perk = "Sprint" },
	Sniper = { primary = "Sniper", secondary = "Pistol", perk = "Camouflage" },
}
local loadouts: { [Player]: Loadout } = {}

ReplicatedStorage.Remotes.SelectPreset.OnServerEvent:Connect(function(player: Player, presetName: unknown)
	local preset = if typeof(presetName) == "string" then PRESETS[presetName] else nil
	if not preset then
		return
	end
	local loadout = table.clone(preset)
	loadouts[player] = loadout
	player:SetAttribute("LoadoutId", HttpService:GenerateGUID(false))
	player:SetAttribute("LoadoutJson", HttpService:JSONEncode(loadout))
end)

Players.PlayerRemoving:Connect(function(player: Player)
	loadouts[player] = nil
end)
