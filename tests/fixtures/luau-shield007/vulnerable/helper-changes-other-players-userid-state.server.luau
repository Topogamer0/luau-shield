-- Vulnerable (v0.2.0 review): the helper changes `state[target.UserId]`, not the sender's state.
-- Party invites keyed by UserId. The sender must be in the lobby; the helper
-- marks the INVITED player (its parameter is also named `player`). The
-- sender's state never changes (the invite expires after 30 s): a client in the lobby fires Invite in a loop
-- and every request clones a GUI and publishes a cross-server message.
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Invite = ReplicatedStorage.Remotes.Invite
local InviteGui = ServerStorage.InviteGui
local state: { [number]: string } = {}

local function setState(player: Player, newState: string)
	state[player.UserId] = newState
end

Invite.OnServerEvent:Connect(function(player: Player, target: unknown) -- expect: luau-shield007
	if state[player.UserId] ~= "Lobby" then
		return
	end
	if typeof(target) ~= "Instance" or not target:IsA("Player") or target.Parent ~= Players then
		return
	end
	setState(target, "Invited")
	InviteGui:Clone().Parent = target:WaitForChild("PlayerGui")
	MessagingService:PublishAsync("Invites", { from = player.UserId, to = target.UserId })
	task.delay(30, function() -- the invite expires
		if state[target.UserId] == "Invited" then
			state[target.UserId] = "Lobby"
		end
	end)
end)
