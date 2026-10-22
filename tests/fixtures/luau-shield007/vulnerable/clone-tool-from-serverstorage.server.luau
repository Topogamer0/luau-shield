-- Vulnerable: the free starter sword is cloned on every request. Exploiters
-- fill their backpack (and the server's memory) with copies.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local sword = ServerStorage.Tools.StarterSword

ReplicatedStorage.Remotes.ClaimStarterSword.OnServerEvent:Connect(function(player) -- expect: luau-shield007
	local copy = sword:Clone()
	copy.Parent = player.Backpack
end)
