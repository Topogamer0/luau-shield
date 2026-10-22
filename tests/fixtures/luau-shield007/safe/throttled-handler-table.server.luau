--!strict
-- Safe: the twin of the vulnerable handler-table-loop. Every handler of the
-- table is wrapped with throttle() when it is connected, so Summon can run at
-- most once per second per player.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local PetRemotes = ReplicatedStorage.Remotes.Pets
local COMPANION = ServerStorage.Pets.Dog

type Handler = (Player, ...unknown) -> ()

local function throttle(handler: Handler, interval: number): Handler
	local last: { [Player]: number } = {}
	return function(player: Player, ...: unknown)
		local now = os.clock()
		if now - (last[player] or -math.huge) < interval then
			return
		end
		last[player] = now
		handler(player, ...)
	end
end

local handlers: { [string]: Handler } = {}

function handlers.Equip(player: Player, slot: unknown)
	if typeof(slot) == "number" and slot >= 1 and slot <= 3 and slot % 1 == 0 then
		player:SetAttribute("EquippedPetSlot", slot)
	end
end

function handlers.Summon(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local previous = character:FindFirstChild("Pet")
	if previous then
		previous:Destroy()
	end
	local pet = COMPANION:Clone()
	pet.Name = "Pet"
	pet.Parent = character
end

for name, handler in handlers do
	PetRemotes[name].OnServerEvent:Connect(throttle(handler, 1))
end
