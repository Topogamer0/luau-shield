--!strict
-- Safe twin of vulnerable/proxy-webhook-shared-settings: the replicated
-- settings only hold values that every player may see.
export type Settings = {
	MaxFeedbackLength: number,
	FeedbackCooldown: number,
}

local Settings: Settings = {
	MaxFeedbackLength = 300,
	FeedbackCooldown = 60,
}

return Settings
