--!strict
-- Vulnerable: no Rojo project; the `client` folder marks this module as client
-- code. It builds the headers that a server relay forwards to a third-party
-- analytics API, so the write key ships with the game: anyone can copy it and
-- flood or poison the studio's dashboards.
local Telemetry = {}

local headers: { [string]: string } = {}
headers["Content-Type"] = "application/json"
headers["X-Api-Key"] = "tlm_live_4Qx9Zr2Lk7Vb1Nw8Tp3Hs6Jd" -- expect: luau-shield008

local queue: { { event: string, at: number } } = {}

function Telemetry.track(event: string)
	table.insert(queue, { event = event, at = os.time() })
end

function Telemetry.flush(): ({ [string]: string }, { { event: string, at: number } })
	local batch = queue
	queue = {}
	return table.clone(headers), batch
end

return Telemetry
