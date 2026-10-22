--!strict
-- Vulnerable: a server module waits for the client to confirm a purchase.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Confirm = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Confirm") :: RemoteFunction

local Confirmation = {}

function Confirmation.ask(player: Player, question: string): boolean
	return Confirm:InvokeClient(player, question) == true -- expect: luau-shield006
end

return Confirmation
