--!strict
-- Safe: game strings that contain "token"/"key" but are not credentials.
local tokenLabel = "Tokens collected: 0"
local keyHint = "Press E to use the key"
local STORE_NAME = "PlayerData_v3"
local SESSION_GUID = game:GetService("HttpService"):GenerateGUID(false)
local accentColor = "#1E90FFAA"

print(tokenLabel, keyHint, STORE_NAME, SESSION_GUID, accentColor)
