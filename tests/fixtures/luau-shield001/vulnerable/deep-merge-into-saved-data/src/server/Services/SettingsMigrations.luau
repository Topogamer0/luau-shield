local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtil = require(ReplicatedStorage.Shared.TableUtil)

local SettingsMigrations = {}

-- Older clients send older settings formats: each migration hands over to the next.
function SettingsMigrations.fromV3(current, incoming)
	return TableUtil.assign(current, incoming)
end

function SettingsMigrations.fromV2(current, incoming)
	if type(incoming) == "table" and incoming.musicVolume ~= nil then
		incoming.MusicVolume = incoming.musicVolume
	end
	return SettingsMigrations.fromV3(current, incoming)
end

function SettingsMigrations.fromV1(current, incoming)
	return SettingsMigrations.fromV2(current, incoming)
end

return SettingsMigrations
