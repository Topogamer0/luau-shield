--!strict
-- The client only sends the text; it never sees the webhook.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Settings)
local SendFeedback = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SendFeedback") :: RemoteEvent

local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Feedback") :: ScreenGui
local box = gui:WaitForChild("Box") :: TextBox
local send = gui:WaitForChild("Send") :: TextButton

send.Activated:Connect(function()
	local text = box.Text
	if #text > 0 and #text <= Settings.MaxFeedbackLength then
		SendFeedback:FireServer(text)
		box.Text = ""
	end
end)
