-- Vulnerable (v0.2.0 review): every player owns a tycoon; `tycoonOwners[player]` is not an admin list.
-- Tycoon game: every player claims a tycoon when they join; `tycoonOwners`
-- maps each player to the tycoon they own. Being in it is not a permission.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tycoons = workspace.Tycoons
local tycoonOwners = {}
local data = {}

Players.PlayerAdded:Connect(function(player)
	data[player] = { Cash = 0 }
	for _, tycoon in Tycoons:GetChildren() do
		if not tycoon:GetAttribute("Taken") then
			tycoon:SetAttribute("Taken", true)
			tycoonOwners[player] = tycoon
			break
		end
	end
end)

ReplicatedStorage.Remotes.BuyDropper.OnServerEvent:Connect(function(player, price)
	if not tycoonOwners[player] then
		return
	end
	data[player].Cash -= price -- expect: luau-shield001
end)
