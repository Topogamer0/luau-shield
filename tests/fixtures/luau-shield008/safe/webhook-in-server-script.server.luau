-- Safe: the same webhook in a server Script. Script sources never replicate
-- to clients (storing it with HttpService:GetSecret is still better).
local HttpService = game:GetService("HttpService")

local FEEDBACK_WEBHOOK = "https://discord.com/api/webhooks/1122334455667788990/FAKEfakeFAKEfake0123456789abcdefghijklmnopqrstuvwxyzFAKEfake"

local function sendFeedback(text: string)
	HttpService:PostAsync(FEEDBACK_WEBHOOK, HttpService:JSONEncode({ content = text }))
end

sendFeedback("Server started")
