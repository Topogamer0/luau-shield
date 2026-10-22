--!strict
-- Rocket launcher, legacy style: the Script inside the Tool asks the holder's
-- client for the mouse position with RemoteFunction:InvokeClient and creates
-- the explosion there. The value a client returns from InvokeClient is as
-- client-controlled as a remote argument, and the typeof check only proves
-- that it is a Vector3.
--
-- Exploit: hook OnClientInvoke to return the position of any player and blow
-- them up from across the map, every RELOAD_TIME seconds. Waiting on the
-- client at all is luau-shield006: a client that never answers keeps this
-- server thread suspended forever.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetMouseHit = ReplicatedStorage.Remotes.GetMouseHit :: RemoteFunction
local tool = script.Parent :: Tool

local RELOAD_TIME = 2
local reloading = false

tool.Activated:Connect(function()
	local player = Players:GetPlayerFromCharacter(tool.Parent)
	if not player or reloading then
		return
	end
	reloading = true

	local target = GetMouseHit:InvokeClient(player) -- expect: luau-shield006
	if typeof(target) == "Vector3" then
		local explosion = Instance.new("Explosion")
		explosion.BlastRadius = 8
		explosion.Position = target -- expect: luau-shield002
		explosion.Parent = workspace
	end

	task.wait(RELOAD_TIME)
	reloading = false
end)
