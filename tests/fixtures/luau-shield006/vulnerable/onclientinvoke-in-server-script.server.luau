-- Vulnerable: OnClientInvoke only runs on clients. Assigning it in a server
-- Script shows the server is designed around asking clients for answers (and
-- the assignment itself does nothing useful on the server).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetSettings = ReplicatedStorage.Remotes.GetSettings :: RemoteFunction

GetSettings.OnClientInvoke = function() -- expect: luau-shield006
	return { music = true }
end
