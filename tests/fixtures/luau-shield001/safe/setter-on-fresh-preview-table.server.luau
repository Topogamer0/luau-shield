-- Safe (v0.2.0 review): a helper sets `Gems` on a preview table the handler just built.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local function setGems(target, v)
	target.Gems = v
	return target
end
ReplicatedStorage.Remotes.Preview.OnServerEvent:Connect(function(player, amount)
	local preview = setGems({ Coins = 0 }, amount)
	ReplicatedStorage.Remotes.Preview:FireClient(player, preview)
end)
