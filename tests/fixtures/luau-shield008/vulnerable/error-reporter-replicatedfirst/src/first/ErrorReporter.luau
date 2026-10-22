--!strict
-- Vulnerable: an error reporter for the loading screen, in ReplicatedFirst.
-- ReplicatedFirst is the first thing sent to every client, so both webhook
-- URLs can be read by anyone who joins. The ptb./canary. subdomains, the old
-- discordapp.com domain and versioned /api/v10/ paths are the same webhooks.
local LogService = game:GetService("LogService")

local WEBHOOKS = {
	errors = "https://ptb.discord.com/api/webhooks/1199887766554433221/FAKEptbTOKENabcdefghijklmnopqrstuvwxyz0123456789FAKEptbTOKEN", -- expect: luau-shield008
	warnings = "https://canary.discordapp.com/api/v10/webhooks/1199887766554433222/FAKEcanaryTOKENabcdefghijklmnopqrstuvwxyz0123456789FAKE", -- expect: luau-shield008
}

type Report = { url: string, message: string }

local ErrorReporter = { queue = {} :: { Report } }

function ErrorReporter.start()
	LogService.MessageOut:Connect(function(message: string, messageType: Enum.MessageType)
		local url = if messageType == Enum.MessageType.MessageError
			then WEBHOOKS.errors
			elseif messageType == Enum.MessageType.MessageWarning then WEBHOOKS.warnings
			else nil
		if url then
			-- sent later through a server relay; the URLs have leaked already
			table.insert(ErrorReporter.queue, { url = url, message = message })
		end
	end)
end

return ErrorReporter
