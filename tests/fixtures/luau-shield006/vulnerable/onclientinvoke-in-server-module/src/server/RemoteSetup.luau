--!strict
-- Vulnerable: the server module that wires the game's RemoteFunctions sets
-- OnClientInvoke where it meant OnServerInvoke. OnClientInvoke is a callback
-- only clients can implement: the server never answers GetSettings, so every
-- client InvokeServer on it waits forever, and the code reads as if the server
-- planned to call InvokeClient on it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local DEFAULT_SETTINGS = table.freeze({ music = true, shadows = true })

local RemoteSetup = {}

function RemoteSetup.init()
	local getSettings = Remotes:WaitForChild("GetSettings") :: RemoteFunction
	getSettings.OnClientInvoke = function() -- expect: luau-shield006
		return DEFAULT_SETTINGS
	end

	local getServerTime = Remotes:WaitForChild("GetServerTime") :: RemoteFunction
	getServerTime.OnServerInvoke = function(_player: Player): number
		return workspace:GetServerTimeNow()
	end
end

return RemoteSetup
