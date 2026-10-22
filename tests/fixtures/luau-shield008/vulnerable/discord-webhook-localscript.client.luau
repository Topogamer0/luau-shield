-- Vulnerable: a LocalScript posts feedback straight to Discord. Every player
-- can read LocalScripts, take the webhook URL and spam or delete it.
local HttpService = game:GetService("HttpService")

local FEEDBACK_WEBHOOK = "https://discord.com/api/webhooks/1122334455667788990/FAKEfakeFAKEfake0123456789abcdefghijklmnopqrstuvwxyzFAKEfake" -- expect: luau-shield008

local function sendFeedback(text: string)
	-- (HttpService does not even work from the client; the secret leaks anyway)
	HttpService:PostAsync(FEEDBACK_WEBHOOK, HttpService:JSONEncode({ content = text }))
end

return sendFeedback
