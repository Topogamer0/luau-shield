-- Safe: the client side of a RemoteFunction. OnClientInvoke belongs in a
-- LocalScript, and server-side rules never run on client code.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetLanguage = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GetLanguage") :: RemoteFunction

GetLanguage.OnClientInvoke = function(): string
	return "en"
end
