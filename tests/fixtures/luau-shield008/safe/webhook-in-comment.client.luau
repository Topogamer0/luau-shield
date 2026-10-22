--!strict
-- Safe: the old webhook only survives in a comment. Clients receive compiled
-- bytecode, not source text, and comments are not part of the bytecode, so
-- this URL never reaches a player. (It is still in the repository history:
-- revoke it if the repository is public.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReportPlayer = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ReportPlayer") :: RemoteEvent

-- Reports now go through the server (ServerScriptService.Reports). Was:
-- local REPORTS_WEBHOOK = "https://discord.com/api/webhooks/1155779911335577990/FAKEoldTOKENabcdefghijklmnopqrstuvwxyz0123456789FAKEoldTOKEN"

local function report(target: Player, reason: string)
	ReportPlayer:FireServer(target.UserId, reason)
end

return report
