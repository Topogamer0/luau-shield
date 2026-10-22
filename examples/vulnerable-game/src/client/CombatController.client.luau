-- Combat controls: click to swing the sword, hold Shift to sprint, press Q
-- to blink to the mouse position.

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

-- Client-side hit detection: find the humanoid under the mouse.
local function swing()
	local part = mouse.Target
	local model = part and part:FindFirstAncestorOfClass("Model")
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if humanoid and model ~= player.Character then
		Remotes.SwingSword:FireServer(humanoid, Config.SwordDamage)
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 and hasSword() then
		swing()
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		Remotes.Sprint:FireServer(Config.SprintSpeed)
	elseif input.KeyCode == Enum.KeyCode.Q then
		Remotes.Blink:FireServer(mouse.Hit.Position + Vector3.new(0, 3, 0))
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		Remotes.Sprint:FireServer(Config.WalkSpeed)
	end
end)
