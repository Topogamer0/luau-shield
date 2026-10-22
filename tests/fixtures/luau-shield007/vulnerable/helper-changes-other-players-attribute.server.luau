-- Vulnerable (v0.2.0 review): the helper sets the attribute of the invited player, not the sender's.
-- Party invites. The sender must be in the lobby; the invited player's
-- "State" attribute becomes "Invited" through a helper whose parameter is
-- also named `player`. The SENDER's state never changes: a client in the
-- lobby fires Invite in a loop and every request clones a GUI.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Invite = ReplicatedStorage.Remotes.Invite
local InviteGui = ServerStorage.InviteGui

local function setState(player: Player, newState: string)
	player:SetAttribute("State", newState)
end

Invite.OnServerEvent:Connect(function(player, target) -- expect: luau-shield007
	if player:GetAttribute("State") ~= "Lobby" then
		return
	end
	if typeof(target) ~= "Instance" or not target:IsA("Player") or target.Parent ~= Players then
		return
	end
	setState(target, "Invited")
	local gui = InviteGui:Clone()
	gui.Parent = target:WaitForChild("PlayerGui")
	task.delay(30, function()
		if target:GetAttribute("State") == "Invited" then
			setState(target, "Lobby")
		end
		gui:Destroy()
	end)
end)
