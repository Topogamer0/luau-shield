-- Safe twin of global-table-dispatch: handlers are registered in _G, but the
-- action name is checked against a fixed allow-list before it is used as the
-- lookup key, so only these two developer-written functions can ever be called.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

_G.ResetCharacter = function(player: Player)
	player:LoadCharacter()
end

_G.ToggleRun = function(player: Player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = if humanoid.WalkSpeed > 16 then 16 else 24
	end
end

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
