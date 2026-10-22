-- Safe: the action name is checked against a fixed set before it is used to
-- look up a handler in _G, so only these two functions can be called.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ALLOWED_ACTIONS = {
	ResetCharacter = true,
	ToggleRun = true,
}

ReplicatedStorage.Remotes.Request.OnServerEvent:Connect(function(player: Player, name: string)
	if not ALLOWED_ACTIONS[name] then
		return
	end
	_G[name](player)
end)
