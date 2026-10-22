--!strict
-- Vulnerable: settings shared by the client UI and the server. Discord blocks
-- requests from Roblox, so the feedback webhook goes through a proxy, but the
-- proxy URL still carries the webhook id and token, and this ModuleScript is in
-- ReplicatedStorage: any client can require it, read the URL, then spam the
-- channel or delete the webhook. (No known webhook format here: the name of
-- the field is what marks the value as a secret.)
export type Settings = {
	MaxFeedbackLength: number,
	FeedbackCooldown: number,
	FeedbackWebhook: string,
}

local Settings: Settings = {
	MaxFeedbackLength = 300,
	FeedbackCooldown = 60,
	FeedbackWebhook = "https://webhook.lewisakura.moe/api/webhooks/1188990011223344556/FAKEproxyTOKEN0123456789abcdefghijklmnopqrstuvwxyzFAKE00", -- expect: luau-shield008
}

return Settings
