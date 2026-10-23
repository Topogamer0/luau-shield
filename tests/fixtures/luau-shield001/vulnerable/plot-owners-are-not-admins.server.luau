-- Vulnerable (v0.2.0 review): plot owners and build permissions are held by every player.
-- Plot building game: every player claims a plot (`plotOwners[player]`) and
-- gets default build permissions (`buildPermissions[player.UserId]`) when the
-- plot is claimed. Neither table is an admin list.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Plots = workspace.Plots
local plotOwners = {}
local buildPermissions = {}
local data = {}

ReplicatedStorage.Remotes.ClaimPlot.OnServerEvent:Connect(function(player)
	if plotOwners[player] then
		return
	end
	for _, plot in Plots:GetChildren() do
		if not plot:GetAttribute("Claimed") then
			plot:SetAttribute("Claimed", true)
			plotOwners[player] = plot
			buildPermissions[player.UserId] = { place = true, delete = true }
			data[player] = { Coins = 100 }
			return
		end
	end
end)

ReplicatedStorage.Remotes.SellBuild.OnServerEvent:Connect(function(player, refund)
	if not plotOwners[player] then
		return
	end
	data[player].Coins += refund -- expect: luau-shield001
end)

ReplicatedStorage.Remotes.PlaceItem.OnServerEvent:Connect(function(player, part, cost)
	if not buildPermissions[player.UserId] then
		return
	end
	part:Destroy() -- expect: luau-shield003
	data[player].Coins -= cost -- expect: luau-shield001
end)
