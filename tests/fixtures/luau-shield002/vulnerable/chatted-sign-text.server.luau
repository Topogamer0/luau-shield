--!strict
-- Shop signs: when a shop owner says "/sign <text>" in chat, the text is
-- written on the sign above their shop.
-- Player.Chatted receives the raw message on the server. The chat window
-- shows a filtered copy, but the sign shows the raw text to every player.
-- Cutting the text to 60 characters is not filtering.
--
-- Exploit: no tool needed, just type "/sign <anything>" in chat.

local Players = game:GetService("Players")

local PREFIX = "/sign "
local MAX_SIGN_LENGTH = 60

local function onChatted(player: Player, message: string)
	if message:sub(1, #PREFIX) ~= PREFIX then
		return
	end

	local shop = workspace.Shops:FindFirstChild(player.Name)
	local label = if shop then shop:FindFirstChild("SignLabel", true) else nil
	if not label or not label:IsA("TextLabel") then
		return
	end

	label.Text = message:sub(#PREFIX + 1, #PREFIX + MAX_SIGN_LENGTH) -- expect: luau-shield002
end

Players.PlayerAdded:Connect(function(player: Player)
	player.Chatted:Connect(function(message: string)
		onChatted(player, message)
	end)
end)
