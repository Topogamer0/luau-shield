-- Vulnerable: an in-game calculator evaluates the expression typed by the
-- player with loadstring. "return 1 + 1" works, but so does
-- "return game:GetService('Players'):ClearAllChildren()".
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Calculate = ReplicatedStorage.Remotes.Calculate :: RemoteFunction

Calculate.OnServerInvoke = function(player: Player, expression: string): number?
	if typeof(expression) ~= "string" or #expression > 100 then
		return nil
	end
	local evaluate = loadstring("return " .. expression) -- expect: luau-shield004
	if not evaluate then
		return nil
	end
	local ok, result = pcall(evaluate)
	return if ok and typeof(result) == "number" then result else nil
end
