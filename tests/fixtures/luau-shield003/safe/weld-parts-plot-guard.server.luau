--!strict
-- Building tool, fixed: both selected parts must pass PlotGuard.isInPlayerPlot
-- before anything is changed. PlotGuard comes from a Wally package that is not
-- part of the checked tree, so luau-shield cannot analyse it; a guard calling
-- an unresolved function whose name starts with "is" is trusted to validate
-- its arguments. The weld is then parented to a validated part (no luau-shield002),
-- and the os.clock() cooldown is the rate limit for Instance.new (no luau-shield007).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotGuard = require(ReplicatedStorage.Packages.PlotGuard)

local WeldParts = ReplicatedStorage.Remotes.WeldParts :: RemoteEvent

local COOLDOWN = 0.5
local lastWeld: { [Player]: number } = {}

WeldParts.OnServerEvent:Connect(function(player: Player, part0: BasePart, part1: BasePart)
	local now = os.clock()
	if now - (lastWeld[player] or 0) < COOLDOWN then
		return
	end
	lastWeld[player] = now

	if not PlotGuard.isInPlayerPlot(player, part0) or not PlotGuard.isInPlayerPlot(player, part1) then
		return
	end
	if not part0:IsA("BasePart") or not part1:IsA("BasePart") or part0 == part1 then
		return
	end

	part0.Anchored = false
	part1.Anchored = false

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part0
	weld.Part1 = part1
	weld.Parent = part0
end)
