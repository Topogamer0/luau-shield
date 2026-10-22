--!strict
-- Vulnerable: a shared configuration module in ReplicatedStorage. Clients can
-- read every ModuleScript in ReplicatedStorage, including this API key.
local Config = {
	NpcModel = "gpt-4o-mini",
	OpenAIKey = "sk-proj-FAKE0kEy1notREAL0123456789abcdefghijkl", -- expect: luau-shield008
	MaxTokens = 200,
}

return Config
