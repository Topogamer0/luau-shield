--!strict
-- Furniture editor with slots: instead of a free CFrame, the client sends the
-- name of a placement slot of its own plot and a rotation index. Both are only
-- used as keys into server data (the plot's Slots folder and the ROTATIONS
-- table), so the CFrame passed to PivotTo is built from server values only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MoveFurniture = ReplicatedStorage.Remotes.MoveFurniture :: RemoteFunction

local ROTATIONS = {
	CFrame.Angles(0, 0, 0),
	CFrame.Angles(0, math.rad(90), 0),
	CFrame.Angles(0, math.rad(180), 0),
	CFrame.Angles(0, math.rad(270), 0),
}

MoveFurniture.OnServerInvoke = function(player: Player, furnitureId: string, slotName: string, rotationIndex: number): boolean
	local plot = workspace.Plots:FindFirstChild(player.Name)
	if not plot then
		return false
	end

	local model = plot.Furniture:FindFirstChild(furnitureId)
	local slot = plot.Slots:FindFirstChild(slotName)
	local rotation = ROTATIONS[rotationIndex]
	if not model or not model:IsA("Model") or not slot or not slot:IsA("BasePart") or not rotation then
		return false
	end

	model:PivotTo(slot.CFrame * rotation)
	return true
end
