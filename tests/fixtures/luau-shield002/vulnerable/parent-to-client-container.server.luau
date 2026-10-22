--!strict
-- Storage chests: the client drags a tool from its backpack onto a chest and
-- sends the tool name plus the chest Model it was dropped on. The tool is
-- looked up in the player's own Backpack (a server lookup), but the new
-- Parent is whatever Instance the client sent.
--
-- Exploit: send another player's Character (it is a Model too) or their
-- chest as the destination. The tool is moved there: restricted tools can be
-- handed to anyone, and items can be pushed into containers that the server
-- considers owned by someone else. IsA("Model") is a type check, not an
-- ownership check.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StoreTool = ReplicatedStorage.Remotes.StoreTool :: RemoteEvent

local function onStoreTool(player: Player, toolName: string, chest: Instance)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local tool = if backpack then backpack:FindFirstChild(toolName) else nil
	if not tool or not tool:IsA("Tool") then
		return
	end

	if typeof(chest) ~= "Instance" or not chest:IsA("Model") then
		return
	end

	tool.Parent = chest -- expect: luau-shield002
end

StoreTool.OnServerEvent:Connect(onStoreTool)
