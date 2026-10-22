--!strict
-- Hat dropping: the client fires DropHat with one of its accessories and the
-- server moves it into a folder in Workspace. Players:GetPlayerFromCharacter
-- on the accessory's Parent must return this player, so only accessories
-- worn by the player's own character can be dropped. The new Parent is a
-- server folder, so there is no luau-shield002 either.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DropHat = ReplicatedStorage.Remotes.DropHat :: RemoteEvent
local DroppedHats = workspace:WaitForChild("DroppedHats")

DropHat.OnServerEvent:Connect(function(player: Player, accessory: Accessory)
	if typeof(accessory) ~= "Instance" or not accessory:IsA("Accessory") then
		return
	end
	if Players:GetPlayerFromCharacter(accessory.Parent) ~= player then
		return
	end

	accessory.Parent = DroppedHats
	accessory:SetAttribute("DroppedBy", player.UserId)
end)
