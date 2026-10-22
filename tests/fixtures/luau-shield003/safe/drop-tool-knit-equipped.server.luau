-- Knit inventory service, fixed: only the tool the player is holding can be
-- dropped. An equipped Tool lives in the character, so `tool.Parent ~=
-- character` rejects the tools held by other players and everything in
-- ReplicatedStorage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local InventoryService = Knit.CreateService({
	Name = "InventoryService",
	Client = {},
})

function InventoryService.Client:DropTool(player, tool)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or typeof(tool) ~= "Instance" or tool.Parent ~= character then
		return false
	end
	if not tool:IsA("Tool") or not tool:FindFirstChild("Handle") then
		return false
	end

	tool.Handle.CanCollide = true
	tool.Handle.CFrame = root.CFrame * CFrame.new(0, 0, -3)
	tool.Parent = workspace
	return true
end

Knit.Start():catch(warn)
