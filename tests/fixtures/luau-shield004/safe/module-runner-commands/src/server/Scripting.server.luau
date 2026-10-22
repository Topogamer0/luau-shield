-- Safe twin of module-runner: the remote sends the name of a macro, and the
-- module runs one of its own functions.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Macros = require(script.Parent.Modules.Macros)

ReplicatedStorage.Remotes.RunScript.OnServerEvent:Connect(function(player: Player, macroName: string)
	Macros.run(player, macroName)
end)
