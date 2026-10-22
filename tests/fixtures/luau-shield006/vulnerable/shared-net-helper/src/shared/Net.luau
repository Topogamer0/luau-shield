--!strict
-- Shared networking helper (ReplicatedStorage.Shared.Net). `invoke` wraps
-- InvokeClient in pcall but has no timeout, so every server caller inherits
-- the hang. The finding is reported here, where InvokeClient is called.
local Net = {}

function Net.invoke(remote: RemoteFunction, player: Player, ...: any): (boolean, any)
	return pcall(remote.InvokeClient, remote, player, ...) -- expect: luau-shield006
end

return Net
