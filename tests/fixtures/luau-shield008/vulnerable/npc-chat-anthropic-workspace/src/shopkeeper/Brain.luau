--!strict
-- Vulnerable: an AI shopkeeper model in Workspace carries its own "brain"
-- ModuleScript. Workspace replicates to clients, ModuleScripts included, so any
-- player can read the Anthropic API key and spend the studio's credits with it.
local HttpService = game:GetService("HttpService")

local Brain = {}

function Brain.reply(prompt: string): string
	local response = HttpService:RequestAsync({
		Url = "https://api.anthropic.com/v1/messages",
		Method = "POST",
		Headers = {
			["x-api-key"] = "sk-ant-api03-FAKEfake0shopkeeper0KEY0123456789abcdefFAKE", -- expect: luau-shield008
			["anthropic-version"] = "2023-06-01",
			["content-type"] = "application/json",
		},
		Body = HttpService:JSONEncode({
			model = "claude-haiku-4-5",
			max_tokens = 200,
			messages = { { role = "user", content = prompt } },
		}),
	})
	local decoded = HttpService:JSONDecode(response.Body)
	return decoded.content[1].text
end

return Brain
