--!strict
-- Safe: daily rewards in a table of handlers connected in a loop (twin of the
-- vulnerable stat-alias-waitforchild entry). The login streak is tracked in
-- the server's copy of the profile; the client only asks to claim.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local DAILY_GEMS = 25
local MAX_STREAK_MULTIPLIER = 7
local GROUP_ID = 4_815_162
local GROUP_BONUS = 100

type Profile = { LastClaimDay: number, Streak: number }

local profiles: { [Player]: Profile } = {}
local groupBonusClaimed: { [Player]: boolean } = {}

local handlers: { [string]: (Player, ...any) -> () } = {}

function handlers.ClaimDaily(player: Player)
	local profile = profiles[player]
	local today = os.time() // 86400
	if not profile or profile.LastClaimDay == today then
		return
	end
	profile.Streak = if profile.LastClaimDay == today - 1 then profile.Streak + 1 else 1
	profile.LastClaimDay = today

	local gems = player:WaitForChild("leaderstats"):WaitForChild("Gems") :: IntValue
	gems.Value += DAILY_GEMS * math.min(profile.Streak, MAX_STREAK_MULTIPLIER)
end

function handlers.ClaimGroupBonus(player: Player)
	if groupBonusClaimed[player] or not player:IsInGroup(GROUP_ID) then
		return
	end
	groupBonusClaimed[player] = true

	local gems = player:WaitForChild("leaderstats"):WaitForChild("Gems") :: IntValue
	gems.Value += GROUP_BONUS
end

for name, handler in handlers do
	local remote = Remotes:WaitForChild(name) :: RemoteEvent
	remote.OnServerEvent:Connect(handler)
end

Players.PlayerAdded:Connect(function(player)
	profiles[player] = { LastClaimDay = 0, Streak = 0 }
end)

Players.PlayerRemoving:Connect(function(player)
	profiles[player] = nil
	groupBonusClaimed[player] = nil
end)
