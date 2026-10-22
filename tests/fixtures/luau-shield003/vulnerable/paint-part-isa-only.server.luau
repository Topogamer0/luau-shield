--!strict
-- Building game paint tool: the client fires PaintPart with the part under
-- the mouse and the chosen colour. The server checks that the part is a
-- BasePart and that the colour is a Color3. IsA is a type check: it says
-- nothing about whose part it is.
--
-- Exploit: fire PaintPart for every BasePart in Workspace: other players'
-- builds, the lobby, the spawn, other players' character limbs. Every base
-- on the server is griefed in a few seconds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PaintPart = ReplicatedStorage.Remotes.PaintPart :: RemoteEvent

local function onPaint(player: Player, part: BasePart, color: Color3)
	if typeof(part) ~= "Instance" or not part:IsA("BasePart") then
		return
	end
	if typeof(color) ~= "Color3" then
		return
	end

	part.Color = color -- expect: luau-shield003
	part.Material = Enum.Material.SmoothPlastic
	part:SetAttribute("PaintedBy", player.UserId)
end

PaintPart.OnServerEvent:Connect(onPaint)
