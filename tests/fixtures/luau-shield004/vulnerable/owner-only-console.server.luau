-- Vulnerable (as far as the analyzer can tell): only the owner may use the
-- console, but the code itself is still client data run with loadstring. If
-- the owner check is ever wrong (or the owner's account is compromised), this
-- is remote code execution. If the console is intended, suppress the finding
-- with `-- luau-shield-ignore: luau-shield004 <reason>` (see the safe twin).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OWNER_ID = 123456789

ReplicatedStorage.Remotes.OwnerConsole.OnServerEvent:Connect(function(player: Player, source: string)
	if player.UserId ~= OWNER_ID then
		return
	end
	local chunk = loadstring(source) -- expect: luau-shield004
	if chunk then
		chunk()
	end
end)
