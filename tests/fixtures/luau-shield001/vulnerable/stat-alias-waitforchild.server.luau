--!strict
-- Vulnerable: reward remotes are declared in a table of handlers and connected
-- in a loop. ClaimDaily scales the reward with the login streak sent by the
-- client; the stat object is a local alias obtained with WaitForChild.
--
-- Exploit: fire ClaimDaily with a streak of 1e6 to receive 25 million gems
-- (once per day is plenty).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local DAILY_GEMS = 25
local GROUP_ID = 4_815_162
local GROUP_BONUS = 100

local lastClaimDay: { [Player]: number } = {}
local groupBonusClaimed: { [Player]: boolean } = {}

local handlers: { [string]: (Player, ...any) -> () } = {}

function handlers.ClaimDaily(player: Player, streak: number)
	local today = os.time() // 86400
	if lastClaimDay[player] == today or typeof(streak) ~= "number" then
		return
	end
	lastClaimDay[player] = today

	local gems = player:WaitForChild("leaderstats"):WaitForChild("Gems") :: IntValue
	gems.Value += DAILY_GEMS * streak -- expect: luau-shield001
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
