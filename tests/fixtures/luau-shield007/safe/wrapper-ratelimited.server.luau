--!strict
-- Safe: the handler is wrapped by a local rate-limiting helper.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local WEBHOOK = HttpService:GetSecret("bug_webhook")

local function rateLimited(seconds: number, handler: (Player) -> ())
	local last: { [Player]: number } = {}
	return function(player: Player)
		local now = os.clock()
		if last[player] and now - last[player] < seconds then
			return
		end
		last[player] = now
		handler(player)
	end
end

local function reportBug(player: Player)
	HttpService:PostAsync(WEBHOOK, HttpService:JSONEncode({ content = `{player.UserId} reported a bug` }))
end

ReplicatedStorage.Remotes.FoundBug.OnServerEvent:Connect(rateLimited(60, reportBug))
