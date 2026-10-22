--!strict
-- Safe: "Shared" here means shared between server scripts. The folder is inside
-- ServerScriptService (see default.project.json), whose contents are never
-- sent to clients, so the webhook stays on the server. (HttpService:GetSecret
-- would still keep it out of the repository.)
local Webhooks = {
	ModLog = "https://discord.com/api/webhooks/1133557799224466880/FAKEmodlogTOKENabcdefghijklmnopqrstuvwxyz0123456789FAKEmodlog",
}

return Webhooks
