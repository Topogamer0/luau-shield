--!strict
-- LocalScript: placement preview. It moves a client-only ghost model to the
-- point under the mouse and echoes the name typed in a TextBox on a preview
-- label. These look like luau-shield002 sinks fed by user input, but this code runs
-- on the client and only changes the local player's own view: server-side
-- rules never run on .client.luau files.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local gui = player:WaitForChild("PlayerGui"):WaitForChild("BuildGui") :: ScreenGui
local nameBox = gui:WaitForChild("NameBox") :: TextBox
local previewLabel = gui:WaitForChild("PreviewLabel") :: TextLabel

local ghost = (ReplicatedStorage:WaitForChild("Furniture"):WaitForChild("Chair") :: Model):Clone()
ghost.Parent = workspace.CurrentCamera

local GRID = 4

RunService.RenderStepped:Connect(function()
	local hit = mouse.Hit.Position
	local snapped = Vector3.new(math.round(hit.X / GRID) * GRID, hit.Y, math.round(hit.Z / GRID) * GRID)
	ghost:PivotTo(CFrame.new(snapped))
end)

nameBox:GetPropertyChangedSignal("Text"):Connect(function()
	previewLabel.Text = `Placing: {nameBox.Text}`
end)
