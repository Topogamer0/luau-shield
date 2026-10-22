-- Safe: the secret is stored with Roblox secrets and read on the server.
local HttpService = game:GetService("HttpService")

local webhook = HttpService:GetSecret("feedback_webhook")
local apiKey = HttpService:GetSecret("openai_key")

print(webhook, apiKey)
