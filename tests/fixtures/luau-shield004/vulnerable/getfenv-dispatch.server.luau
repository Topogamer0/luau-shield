-- Vulnerable: actions are dispatched by looking the function name up in the
-- script environment. The client can call ANY global function (require,
-- loadstring, setfenv...) with its own arguments.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DoAction = ReplicatedStorage.Remotes.DoAction :: RemoteEvent

function jump(player: Player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Jump = true
	end
end

DoAction.OnServerEvent:Connect(function(player: Player, action: string, ...: any)
	getfenv()[action](player, ...) -- expect: luau-shield004
end)
