--!strict
-- Safe: game strings that contain "token"/"key" but are not credentials. A
-- value stored under a credential-like name (tokenLabel) is only a secret
-- candidate from 16 characters up; this label is shorter.
local tokenLabel = "Tokens: 0"
local keyHint = "Press E to use the key"
local STORE_NAME = "PlayerData_v3"
local SESSION_GUID = game:GetService("HttpService"):GenerateGUID(false)
local accentColor = "#1E90FFAA"

print(tokenLabel, keyHint, STORE_NAME, SESSION_GUID, accentColor)
