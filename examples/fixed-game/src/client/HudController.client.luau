-- HUD: settings menu, fireworks, bug reports, coin gifts and the admin
-- console. Expects a ScreenGui named "HUD" in StarterGui.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local hud = player:WaitForChild("PlayerGui"):WaitForChild("HUD")

-- Settings menu: every toggle flips one setting and saves the menu.
local settings = { Music = true, Sfx = true, ShowTips = true }
for name in settings do
	local toggle = hud.Settings[name] :: TextButton
	toggle.Activated:Connect(function()
		settings[name] = not settings[name]
		toggle.Text = `{name}: {if settings[name] then "On" else "Off"}`
		Remotes.SaveSettings:FireServer({ Settings = settings })
	end)
end

-- Fireworks: "Next" cycles through the fireworks, F launches one.
local fireworkIndex = 1
hud.Fireworks.Next.Activated:Connect(function()
	fireworkIndex = fireworkIndex % #Config.Fireworks + 1
	hud.Fireworks.Label.Text = Config.Fireworks[fireworkIndex]
end)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == Enum.KeyCode.F then
		Remotes.LaunchFirework:FireServer(Config.Fireworks[fireworkIndex])
	end
end)

-- Bug report board (one report per minute, checked by the server).
local report = hud.BugReport
report.Send.Activated:Connect(function()
	local text = report.Message.Text
	if #text == 0 or #text > Config.BugReportMaxLength then
		return
	end
	Remotes.SubmitBugReport:FireServer(report.Category.Text, text)
	Remotes.TrackEvent:FireServer("bug_report_sent", report.Category.Text)
	report.Message.Text = ""
end)

-- Coin gifts: send coins to another player, and answer offers from others.
local trade = hud.Trade
trade.Send.Activated:Connect(function()
	local target = Players:FindFirstChild(trade.PlayerName.Text)
	local coins = tonumber(trade.Amount.Text)
	if target and coins then
		Remotes.OfferTrade:FireServer(target.UserId, coins)
	end
end)

local prompt = hud.TradePrompt
Remotes.TradeRequest.OnClientEvent:Connect(function(fromName: string, coins: number)
	prompt.Message.Text = `{fromName} wants to send you {coins} coins`
	prompt.Visible = true
end)
prompt.Accept.Activated:Connect(function()
	prompt.Visible = false
	Remotes.RespondTrade:FireServer(true)
end)
prompt.Decline.Activated:Connect(function()
	prompt.Visible = false
	Remotes.RespondTrade:FireServer(false)
end)

-- Admin console (F2). The server decides who is an admin.
local console = hud.AdminConsole
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == Enum.KeyCode.F2 then
		console.Visible = not console.Visible
	end
end)
console.Run.Activated:Connect(function()
	Remotes.AdminCommand:FireServer(console.Command.Text, console.Argument.Text)
end)
