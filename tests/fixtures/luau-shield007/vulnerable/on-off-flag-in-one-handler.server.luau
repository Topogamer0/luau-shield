-- Vulnerable (v0.2.0 review): a client on/off flag turns the state on and off in the same handler.
-- One remote turns an effect on or off, the client chooses. Turning it on
-- tests and changes the state; turning it off (same remote) resets it:
-- the client alternates SetAura:FireServer(true) / (false) and every `true`
-- clones the aura.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local SetAura = ReplicatedStorage.Remotes.SetAura
local AuraTemplate = ServerStorage.Effects.Aura
local auraState: { [Player]: string } = {}
local auras: { [Player]: Instance } = {}

SetAura.OnServerEvent:Connect(function(player: Player, enabled: unknown) -- expect: luau-shield007
	local character = player.Character
	if not character then
		return
	end
	if enabled == true then
		if auraState[player] == "On" then
			return
		end
		auraState[player] = "On"
		local aura = AuraTemplate:Clone()
		aura.Parent = character
		auras[player] = aura
	else
		auraState[player] = "Off"
		if auras[player] then
			auras[player]:Destroy()
			auras[player] = nil
		end
	end
end)
