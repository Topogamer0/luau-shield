--!strict
-- Inventory UI, fixed: the client sends the tool's NAME, not the Tool. The
-- server looks it up in the player's own Backpack. A lookup the server does
-- with a client key returns a server value: whatever the client sends, the
-- result can only be one of this player's tools (or nil).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local t = require(ReplicatedStorage.Packages.t)

local EquipTool = ReplicatedStorage.Remotes.EquipTool :: RemoteEvent

local isToolName = t.string

EquipTool.OnServerEvent:Connect(function(player: Player, toolName: string)
	if not isToolName(toolName) then
		return
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	local tool = if backpack then backpack:FindFirstChild(toolName) else nil
	if not tool or not tool:IsA("Tool") then
		return
	end

	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	humanoid:UnequipTools()
	tool.Parent = player.Character
end)
