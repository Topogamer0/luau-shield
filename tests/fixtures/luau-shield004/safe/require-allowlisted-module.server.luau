-- Safe: the client picks a weapon by name, and the ModuleScript is looked up
-- in a server-side table of known modules (never by client-provided id).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Weapons = ServerStorage.Weapons
local WEAPON_MODULES = {
	Sword = Weapons.Sword,
	Bow = Weapons.Bow,
}

ReplicatedStorage.Remotes.EquipWeapon.OnServerEvent:Connect(function(player: Player, weaponName: string)
	local module = WEAPON_MODULES[weaponName]
	if not module then
		return
	end
	local weapon = require(module)
	weapon.equip(player)
end)
