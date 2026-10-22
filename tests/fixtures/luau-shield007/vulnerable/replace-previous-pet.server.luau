--!strict
-- Vulnerable: summoning a pet destroys the previous one and clones a new one.
-- summoned[player] is read and written, but the read is not an early-return
-- guard: nothing stops the next request. An exploiter fires SummonPet in a
-- loop and the server keeps cloning and destroying models.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local COMPANION = ServerStorage.Pets.Cat
local summoned: { [Player]: Model } = {}

ReplicatedStorage.Remotes.SummonPet.OnServerEvent:Connect(function(player: Player) -- expect: luau-shield007
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	if summoned[player] then
		summoned[player]:Destroy()
	end
	local pet = COMPANION:Clone()
	pet:PivotTo(root.CFrame * CFrame.new(3, 0, 0))
	pet.Parent = workspace.Pets
	summoned[player] = pet
end)

Players.PlayerRemoving:Connect(function(player: Player)
	local pet = summoned[player]
	if pet then
		pet:Destroy()
	end
	summoned[player] = nil
end)
