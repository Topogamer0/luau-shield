-- Vulnerable (v0.2.0 review): `data[name].Value` with `name = "Gems"` is the Gems currency.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remote = ReplicatedStorage.Remotes.CompleteQuest

remote.OnServerEvent:Connect(function(player, questId, gems)
	local data = player:FindFirstChild("Data")
	if not data then return end
	local name = "Gems"
	data[name].Value += gems -- expect: luau-shield001
end)
