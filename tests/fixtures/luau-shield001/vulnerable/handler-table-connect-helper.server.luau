-- Vulnerable (v0.2.0 review): a helper wraps and connects each handler of a table; the last handler must still be analysed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage.Remotes

local Handlers = {}

function Handlers.EquipPet(player, petId)
	if typeof(petId) ~= "string" then
		return
	end
	player:SetAttribute("EquippedPet", petId:sub(1, 32)) -- expect: luau-shield002
end

function Handlers.SellPet(player, amount)
	player.leaderstats.Coins.Value += amount -- expect: luau-shield001
end

-- Wrap every handler so that errors are logged with the remote name.
local function connect(name, handler)
	Remotes[name].OnServerEvent:Connect(function(player, ...)
		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn(name, err)
		end
	end)
end

for name, handler in pairs(Handlers) do
	connect(name, handler)
end
