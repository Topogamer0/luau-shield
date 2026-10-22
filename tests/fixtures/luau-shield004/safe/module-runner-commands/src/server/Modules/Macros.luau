--!strict
local Macros = {}

local LIST: { [string]: (Player) -> () } = {
	wave = function(player)
		print(`{player.Name} waves`)
	end,
}

function Macros.run(player: Player, name: string)
	local macro = LIST[name]
	if macro then
		macro(player)
	end
end

return Macros
