--!strict
-- "Sandbox" that only sets an environment: setfenv does not make loadstring
-- safe, the code can still reach game services through the functions it gets.
local Sandbox = {}

function Sandbox.run(player: Player, source: string)
	local chunk = loadstring(source) -- expect: luau-shield004
	if not chunk then
		return
	end
	setfenv(chunk, { print = print, player = player })
	chunk()
end

return Sandbox
