-- Knit inventory service: the hotbar's "drop" button calls
-- InventoryService:DropTool(tool). Knit client methods are remote handlers,
-- so `tool` is chosen by the client. The server checks that it is a Tool with
-- a Handle and drops it in front of the player. Assigning a property on
-- something reached through the Instance (tool.Handle.CanCollide) is a use.
-- The new CFrame and Parent are server values: no luau-shield002.
--
-- Exploit: call DropTool with the sword another player is holding (it lives
-- in their character, in Workspace). It is pulled out of their hand and
-- dropped at the exploiter's feet: every rare item on the server can be
-- stolen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local InventoryService = Knit.CreateService({
	Name = "InventoryService",
	Client = {},
})

function InventoryService.Client:DropTool(player, tool)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or typeof(tool) ~= "Instance" or not tool:IsA("Tool") or not tool:FindFirstChild("Handle") then
		return false
	end

	tool.Handle.CanCollide = true -- expect: luau-shield003
	tool.Handle.CFrame = root.CFrame * CFrame.new(0, 0, -3)
	tool.Parent = workspace
	return true
end

Knit.Start():catch(warn)
