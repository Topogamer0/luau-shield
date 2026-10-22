--!strict
-- Health regeneration is simulated on the client so the health bar is smooth,
-- and the client reports its vitals a few times per second over an
-- UnreliableRemoteEvent. The server copies the report onto the Humanoid.
--
-- Exploit: report { health = 1e6, maxHealth = 1e6 } after every hit and never
-- die. Every field of a table sent by the client is client-controlled.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

type VitalsReport = {
	health: number,
	maxHealth: number,
}

local ReportVitals = ReplicatedStorage.Remotes.ReportVitals :: UnreliableRemoteEvent

ReportVitals.OnServerEvent:Connect(function(player: Player, report: VitalsReport)
	if typeof(report) ~= "table" then
		return
	end

	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	humanoid.MaxHealth = report.maxHealth -- expect: luau-shield002
	humanoid.Health = report.health -- expect: luau-shield002
end)
