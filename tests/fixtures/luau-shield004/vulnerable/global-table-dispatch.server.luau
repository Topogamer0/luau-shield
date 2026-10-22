-- Vulnerable: handlers are registered in _G and looked up by a name chosen by
-- the client. Anything stored in _G by any server script becomes callable.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

_G.ResetCharacter = function(player: Player)
	player:LoadCharacter()
end

ReplicatedStorage.Remotes.Request.OnServerEvent:Connect(function(player: Player, name: string)
	if typeof(name) ~= "string" then
		return
	end
	local handler = _G[name]
	handler(player) -- expect: luau-shield004
end)
