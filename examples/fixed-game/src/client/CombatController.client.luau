-- Combat controls: click to swing the sword, hold Shift to sprint, press Q
-- to blink towards the mouse position.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local function hasSword(): boolean
	local character = player.Character
	return character ~= nil and character:FindFirstChildOfClass("Tool") ~= nil
end

-- The point under the mouse, limited to the blink distance (the server
-- checks the distance again).
local function blinkTarget(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local offset = mouse.Hit.Position + Vector3.new(0, 3, 0) - root.Position
	if offset.Magnitude > Config.BlinkDistance then
		offset = offset.Unit * Config.BlinkDistance
	end
	return root.Position + offset
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 and hasSword() then
		Remotes.SwingSword:FireServer() -- hit detection and damage are server-side
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		Remotes.Sprint:FireServer(true)
	elseif input.KeyCode == Enum.KeyCode.Q then
		local target = blinkTarget()
		if target then
			Remotes.Blink:FireServer(target)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		Remotes.Sprint:FireServer(false)
	end
end)
