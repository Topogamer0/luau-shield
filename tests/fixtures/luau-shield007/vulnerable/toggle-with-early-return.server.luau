-- Vulnerable (v0.2.0 review): a toggle written with an early return flips the state on every request.
-- A shield toggle written with an early return: when the shield is on, the
-- request turns it off and returns; otherwise it turns it on and creates a
-- ForceField. Every second request creates a ForceField: a client firing
-- ToggleShield in a loop creates thousands of instances.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToggleShield = ReplicatedStorage.Remotes.ToggleShield
local mode: { [Player]: string } = {}
local shields: { [Player]: ForceField } = {}

ToggleShield.OnServerEvent:Connect(function(player: Player) -- expect: luau-shield007
	local character = player.Character
	if not character then
		return
	end
	if mode[player] == "Shielded" then
		mode[player] = "Normal"
		if shields[player] then
			shields[player]:Destroy()
			shields[player] = nil
		end
		return
	end
	mode[player] = "Shielded"
	local ff = Instance.new("ForceField")
	ff.Parent = character
	shields[player] = ff
end)
