-- Debug helper: logs and passes its values through.
local Trace = {}
function Trace.pass(label: string, ...)
	if Trace.enabled then
		print("[trace]", label, ...)
	end
	return ...
end
Trace.enabled = false
return Trace
