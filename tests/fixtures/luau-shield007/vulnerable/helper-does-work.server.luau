-- Vulnerable: the expensive work is in a local helper, but it still runs on
-- every request of the Emote remote.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local function playEffect(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local effect = ServerStorage.Effects.Sparkles:Clone()
	effect.Parent = character
	task.delay(2, function()
		effect:Destroy()
	end)
end

ReplicatedStorage.Remotes.Emote.OnServerEvent:Connect(function(player: Player) -- expect: luau-shield007
	playEffect(player)
end)
