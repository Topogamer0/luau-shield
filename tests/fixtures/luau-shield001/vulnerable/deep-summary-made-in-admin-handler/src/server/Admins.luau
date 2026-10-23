local Admins = {}
local IDS = { [12345] = true }
function Admins.isAdmin(player)
	return IDS[player.UserId] == true
end
return Admins
