-- Vulnerable (v0.2.0 review): the helper changes the invited player's state, not the sender's.
-- Party invites. The sender must be in the lobby; the invited player's state
-- becomes "Invited" (through a helper whose parameter is also named
-- `player`) and expires after 30 seconds. The SENDER's state never changes:
-- a client in the lobby can fire Invite in a loop, and every request clones
-- a GUI.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Invite = ReplicatedStorage.Remotes.Invite
local InviteGui = ServerStorage.InviteGui
local state = {}

local function setState(player, newState)
	state[player] = newState
end

Invite.OnServerEvent:Connect(function(player, target) -- expect: luau-shield007
	if state[player] ~= "Lobby" then
		return
	end
	if typeof(target) ~= "Instance" or not target:IsA("Player") or target.Parent ~= Players then
		return
	end
	setState(target, "Invited")
	local gui = InviteGui:Clone()
	gui.Parent = target:WaitForChild("PlayerGui")
	task.delay(30, function()
		if state[target] == "Invited" then
			setState(target, "Lobby")
		end
		gui:Destroy()
	end)
end)
