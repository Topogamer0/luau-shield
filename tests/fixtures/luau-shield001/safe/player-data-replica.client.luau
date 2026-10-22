--!strict
-- Safe (looks scary): a LocalScript keeps a copy of the player's own saved
-- data for the UI. The server pushes changes with DataChanged and the client
-- writes them into its copy with whatever key and value it receives. It also
-- subtracts prices optimistically, and a Studio-only chat command writes a
-- typed number to `data.Coins` (in a server Script that would be a finding).
-- None of this matters: it only changes this client's copy, and the server
-- checks every purchase itself. luau-shield's server-side rules never run on
-- *.client.luau files.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DataChanged = Remotes:WaitForChild("DataChanged") :: RemoteEvent
local GetData = Remotes:WaitForChild("GetData") :: RemoteFunction
local BuyItem = Remotes:WaitForChild("BuyItem") :: RemoteEvent

local player = Players.LocalPlayer
local hud = player:WaitForChild("PlayerGui"):WaitForChild("HUD")
local coinsLabel = hud:WaitForChild("Coins") :: TextLabel

local data: { [string]: any } = GetData:InvokeServer()

local function render()
	coinsLabel.Text = `{data.Coins} coins`
end

DataChanged.OnClientEvent:Connect(function(key: string, value: any)
	data[key] = value
	render()
end)

for _, button in hud:WaitForChild("Shop"):GetChildren() do
	if button:IsA("TextButton") then
		button.Activated:Connect(function()
			local price = button:GetAttribute("Price") :: number
			if data.Coins >= price then
				data.Coins -= price -- optimistic: DataChanged corrects it if refused
				render()
				BuyItem:FireServer(button.Name)
			end
		end)
	end
end

-- Studio-only helper: preview the HUD with any balance by typing
-- "/previewcoins 123456789" in chat.
if RunService:IsStudio() then
	player.Chatted:Connect(function(message: string)
		if string.sub(message, 1, 14) == "/previewcoins " then
			data.Coins = tonumber(string.sub(message, 15)) or 0
			render()
		end
	end)
end

render()
