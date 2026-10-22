--!strict
-- Vulnerable: a party invite is a RemoteFunction that relays the question to
-- the invited player with InvokeClient and returns their answer. If the
-- invited player is an exploiter that never answers, the server thread and
-- the inviter's own InvokeServer call hang forever (the inviter's UI stays on
-- "Waiting..."), and every new invite parks one more server thread.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage.Remotes
local InviteToParty = Remotes.InviteToParty :: RemoteFunction
local AskJoinParty = Remotes.AskJoinParty :: RemoteFunction

local parties: { [Player]: { Player } } = {}

InviteToParty.OnServerInvoke = function(player: Player, targetUserId: unknown): boolean
	if typeof(targetUserId) ~= "number" then
		return false
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player then
		return false
	end
	local accepted = AskJoinParty:InvokeClient(target, player.Name) -- expect: luau-shield006
	if accepted ~= true then
		return false
	end
	local party = parties[player] or { player }
	table.insert(party, target)
	parties[player] = party
	return true
end
