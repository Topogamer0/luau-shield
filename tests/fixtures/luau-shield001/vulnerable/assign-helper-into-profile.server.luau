-- Vulnerable (v0.2.0 review): the same assign helper copies the client's amount into a saved profile.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local profiles = {}
local function assign(target, source)
	for k, v in source do
		target[k] = v -- expect: luau-shield001
	end
	return target
end
ReplicatedStorage.Remotes.Gift.OnServerEvent:Connect(function(player, amount)
	assign(profiles[player], { Gems = amount })
end)
