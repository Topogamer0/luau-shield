-- Vulnerable: the "script editor" remote passes the player's code to a
-- server module, which compiles it with loadstring.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Sandbox = require(script.Parent.Modules.Sandbox)

ReplicatedStorage.Remotes.RunScript.OnServerEvent:Connect(function(player: Player, source: string)
	Sandbox.run(player, source)
end)
