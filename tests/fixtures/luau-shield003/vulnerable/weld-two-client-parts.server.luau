--!strict
-- Building tool: the player selects two parts and the client fires WeldParts
-- with both. The server unanchors them and welds them together. Two
-- untrusted Instances means two luau-shield003 findings, one per parameter, each on
-- the first statement that uses it. Parenting the weld to part0 also gives
-- the new weld a client-chosen Parent (luau-shield002).
--
-- Exploit: fire WeldParts with (workspace.Lobby.Floor, workspace.Lobby.Roof):
-- the lobby falls apart. Or with (someone.Character.HumanoidRootPart,
-- workspace.SpinningTrap) to weld another player to a trap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeldParts = ReplicatedStorage.Remotes.WeldParts :: RemoteEvent

local COOLDOWN = 0.5
local lastWeld: { [Player]: number } = {}

WeldParts.OnServerEvent:Connect(function(player: Player, part0: BasePart, part1: BasePart)
	local now = os.clock()
	if now - (lastWeld[player] or 0) < COOLDOWN then
		return
	end
	lastWeld[player] = now

	if typeof(part0) ~= "Instance" or typeof(part1) ~= "Instance" then
		return
	end
	if not part0:IsA("BasePart") or not part1:IsA("BasePart") or part0 == part1 then
		return
	end

	part0.Anchored = false -- expect: luau-shield003
	part1.Anchored = false -- expect: luau-shield003

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part0
	weld.Part1 = part1
	weld.Parent = part0 -- expect: luau-shield002
end)
