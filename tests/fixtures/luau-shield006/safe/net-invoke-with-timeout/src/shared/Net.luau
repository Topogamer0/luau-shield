--!strict
-- Shared networking helper (ReplicatedStorage.Shared.Net). InvokeClient runs
-- in its own deferred thread; the caller is resumed by the answer or by the
-- timeout, whichever comes first, and a player that has not answered yet is
-- not asked again, so at most one thread per player can be left waiting.
local Net = {}

local inFlight: { [Player]: boolean } = {}

function Net.invokeClient(remote: RemoteFunction, player: Player, timeout: number, ...: any): (boolean, any)
	if inFlight[player] then
		return false, "busy"
	end
	inFlight[player] = true
	local caller = coroutine.running()
	local args = table.pack(...)
	local finished = false

	local function finish(ok: boolean, result: any)
		if finished then
			return
		end
		finished = true
		task.spawn(caller, ok, result)
	end

	task.defer(function()
		finish(pcall(remote.InvokeClient, remote, player, table.unpack(args, 1, args.n)))
		inFlight[player] = nil
	end)
	task.delay(timeout, finish, false, "timed out")
	return coroutine.yield()
end

return Net
