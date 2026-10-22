-- Vulnerable (v0.2.0 review): a toggle written as two ifs on a local copy.
-- Fly toggle written as two separate ifs on a local read before both.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ToggleFly = ReplicatedStorage.Remotes.ToggleFly
local FlyEffects = ServerStorage.Effects.Fly
local mode: { [Player]: string } = {}

ToggleFly.OnServerEvent:Connect(function(player: Player) -- expect: luau-shield007
	local character = player.Character
	if not character then
		return
	end
	local current = mode[player]
	if current == "Flying" then
		mode[player] = "Walking"
		local old = character:FindFirstChild("FlyEffects")
		if old then
			old:Destroy()
		end
	end
	if current ~= "Flying" then
		mode[player] = "Flying"
		local effects = FlyEffects:Clone()
		effects.Name = "FlyEffects"
		effects.Parent = character
	end
end)
