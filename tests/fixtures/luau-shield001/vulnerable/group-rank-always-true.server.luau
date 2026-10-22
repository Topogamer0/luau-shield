-- Vulnerable (v0.2.0 review): `GetRankInGroup(G) >= 0` holds for everybody.
-- Guests and every player have rank >= 0 in any group.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GROUP_ID = 4567890
local data = {}

ReplicatedStorage.Remotes.Gate0.OnServerEvent:Connect(function(player, amount)
	if player:GetRankInGroup(GROUP_ID) >= 0 then
		data[player].Coins += amount -- expect: luau-shield001
	end
end)
