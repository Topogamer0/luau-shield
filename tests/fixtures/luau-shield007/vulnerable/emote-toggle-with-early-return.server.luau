-- Vulnerable (v0.2.0 review): an emote toggle with an early return clones the prop every other request.
-- Emote toggle: `if ... then stop; return elseif ... end` then start.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Emote = ReplicatedStorage.Remotes.Emote
local Props = ServerStorage.EmoteProps
local emoting: { [Player]: string } = {}

Emote.OnServerEvent:Connect(function(player: Player) -- expect: luau-shield007
	local character = player.Character
	if not character then
		return
	end
	if emoting[player] == "Dancing" then
		emoting[player] = "Idle"
		local prop = character:FindFirstChild("DanceProp")
		if prop then
			prop:Destroy()
		end
		return
	end
	emoting[player] = "Dancing"
	local prop = Props.DanceProp:Clone()
	prop.Parent = character
end)
