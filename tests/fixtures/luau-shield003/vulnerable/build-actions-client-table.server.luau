--!strict
-- Sandbox building: every build action has its own RemoteEvent under
-- Remotes.Build, and the handlers live in a table connected in a loop. Each
-- remote carries one table describing the action. The block to act on is a
-- FIELD of that client table (data.target), so it is an Instance chosen by
-- the client, exactly like a parameter.
--
-- Exploit: fire RemoveBlock with { target = workspace.Lobby.Floor } or with
-- another player's build, and ColorBlock with { target = someoneElse.Character.Head,
-- color = ... }. Nothing ties the block to the player's own plot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildRemotes = ReplicatedStorage.Remotes.Build

export type BuildRequest = {
	target: BasePart,
	color: Color3?,
}

local handlers: { [string]: (Player, BuildRequest) -> () } = {}

function handlers.RemoveBlock(player: Player, data: BuildRequest)
	if typeof(data) ~= "table" or typeof(data.target) ~= "Instance" then
		return
	end
	data.target:Destroy() -- expect: luau-shield003
end

function handlers.ColorBlock(player: Player, data: BuildRequest)
	if typeof(data) ~= "table" or typeof(data.color) ~= "Color3" then
		return
	end
	data.target.Color = data.color -- expect: luau-shield003
end

for name, handler in handlers do
	local remote = BuildRemotes:WaitForChild(name) :: RemoteEvent
	remote.OnServerEvent:Connect(handler)
end
