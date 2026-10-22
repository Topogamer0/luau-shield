-- Safe: loadstring is used with a constant chunk written by the developer
-- (for example to check that LoadStringEnabled is on); no client data.
local ok = pcall(function()
	local chunk = loadstring("return 1 + 1")
	assert(chunk and chunk() == 2)
end)
if not ok then
	warn("LoadStringEnabled is off")
end
