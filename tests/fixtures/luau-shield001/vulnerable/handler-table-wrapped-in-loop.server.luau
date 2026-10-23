-- Vulnerable (v0.2.0 review): handlers stored in a table and connected through a wrapper closure in a loop; every handler must be analysed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage.Remotes

local Handlers = {}

function Handlers.AddCoins(player, amount)
	player.leaderstats.Coins.Value += amount -- expect: luau-shield001
end

function Handlers.SetTitle(player, title)
	if typeof(title) ~= "string" or #title > 20 then
		return
	end
	player:SetAttribute("Title", title) -- expect: luau-shield002
end

-- Every handler is wrapped so that an error in one request is logged.
for name, handler in pairs(Handlers) do
	Remotes[name].OnServerEvent:Connect(function(player, ...)
		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn(name, err)
		end
	end)
end
