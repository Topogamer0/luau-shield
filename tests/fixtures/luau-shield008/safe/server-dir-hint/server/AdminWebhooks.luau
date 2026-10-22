--!strict
-- Safe: no Rojo project, and the module is in a `server` folder, so it is
-- server code: its source is never sent to clients.
local AdminWebhooks = {}

AdminWebhooks.Bans = "https://discord.com/api/webhooks/1144668800224466880/FAKEbansTOKENabcdefghijklmnopqrstuvwxyz0123456789FAKEbansTOKEN"
AdminWebhooks.Reports = "https://discordapp.com/api/webhooks/1144668800224466881/FAKEreportsTOKENabcdefghijklmnopqrstuvwxyz0123456789FAKE"

return AdminWebhooks
