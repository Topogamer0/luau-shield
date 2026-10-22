-- Safe: requests go through the project's rate limiter package (not part of
-- the checked tree), which is recognised by its name.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RateLimiter = require(ReplicatedStorage.Packages.RateLimiter)

local limiter = RateLimiter.new(1, 5)
local sword = ServerStorage.Tools.StarterSword

ReplicatedStorage.Remotes.ClaimStarterSword.OnServerEvent:Connect(function(player)
	if not limiter:CheckRate(player) then
		return
	end
	if player.Backpack:FindFirstChild(sword.Name) then
		return
	end
	sword:Clone().Parent = player.Backpack
end)
