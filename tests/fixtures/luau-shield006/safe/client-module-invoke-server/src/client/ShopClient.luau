--!strict
-- Safe: a client ModuleScript (StarterPlayerScripts) asking the SERVER with
-- InvokeServer, and answering server questions with OnClientInvoke. Both are
-- the normal client-side API.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetPrices = Remotes:WaitForChild("GetPrices") :: RemoteFunction
local AskConfirm = Remotes:WaitForChild("AskConfirm") :: RemoteFunction

local ShopClient = {}

function ShopClient.prices(): { [string]: number }
	return GetPrices:InvokeServer()
end

AskConfirm.OnClientInvoke = function(question: string): boolean
	return question ~= ""
end

return ShopClient
