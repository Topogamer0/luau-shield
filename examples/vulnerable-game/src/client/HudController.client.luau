-- HUD: settings menu, fireworks, bug reports, coin gifts and the hidden
-- developer console. Expects a ScreenGui named "HUD" in StarterGui.

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

-- Bug report board.
local report = hud.BugReport
report.Send.Activated:Connect(function()
	Remotes.SubmitBugReport:FireServer(report.Category.Text, report.Message.Text)
	Remotes.TrackEvent:FireServer("bug_report_sent", { category = report.Category.Text })
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

Remotes.ConfirmTrade.OnClientInvoke = function(fromName: string, coins: number): boolean
	local prompt = hud.TradePrompt
	prompt.Message.Text = `{fromName} wants to send you {coins} coins`
	prompt.Visible = true
	local answered = Instance.new("BindableEvent")
	local accept = prompt.Accept.Activated:Connect(function()
		answered:Fire(true)
	end)
	local decline = prompt.Decline.Activated:Connect(function()
		answered:Fire(false)
	end)
	local accepted = answered.Event:Wait()
	accept:Disconnect()
	decline:Disconnect()
	answered:Destroy()
	prompt.Visible = false
	return accepted
end

-- Developer console: hidden until the admin password is typed.
local console = hud.DevConsole
console.Password.FocusLost:Connect(function()
	console.Editor.Visible = console.Password.Text == Config.AdminPassword
end)
console.Editor.Run.Activated:Connect(function()
	Remotes.AdminCommand:FireServer(console.Password.Text, console.Editor.Source.Text)
end)
