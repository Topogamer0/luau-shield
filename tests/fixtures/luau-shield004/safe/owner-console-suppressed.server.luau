-- Safe (accepted risk): the same owner-only console as the vulnerable twin,
-- deliberately kept and documented with an inline suppression.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OWNER_ID = 123456789

ReplicatedStorage.Remotes.OwnerConsole.OnServerEvent:Connect(function(player: Player, source: string)
	if player.UserId ~= OWNER_ID then
		return
	end
	-- luau-shield-ignore: luau-shield004 owner-only console, reviewed and accepted
	local chunk = loadstring(source)
	if chunk then
		chunk()
	end
end)
