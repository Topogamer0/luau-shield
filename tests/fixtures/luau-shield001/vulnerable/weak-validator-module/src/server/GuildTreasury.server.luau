-- Vulnerable: depositing gold into the guild treasury. The amount goes through
-- Validate.isPositiveNumber from the shared module. luau-shield analyses that
-- function: it proves the type, a lower bound and (because `value > 0` must
-- be true) that the value is not NaN, but nothing bounds it from above, not
-- even by the gold the player owns.
--
-- Exploit: from a throwaway alt in the guild, fire DepositGold with 1e15. The
-- alt's gold goes deeply negative, and the shared treasury that every member
-- spends from gains 1e15 gold.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Validate = require(ReplicatedStorage.Shared.Validate)

local DepositGold = ReplicatedStorage.Remotes.DepositGold :: RemoteEvent

type Guild = {
	Name: string,
	Gold: number,
}

local guilds: { [string]: Guild } = {}
local guildOf: { [Player]: string } = {}

DepositGold.OnServerEvent:Connect(function(player: Player, amount: number)
	if not Validate.isPositiveNumber(amount) then
		return
	end
	local guild = guilds[guildOf[player]]
	local gold = player.leaderstats:FindFirstChild("Gold")
	if not guild or not gold then
		return
	end

	gold.Value -= amount -- expect: luau-shield001
	guild.Gold += amount -- expect: luau-shield001
end)
