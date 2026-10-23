-- Vulnerable (v0.2.0 review): a deep text limiter whose maximum length comes from the client.
-- Deep text limiter: the maximum length comes from the client request.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local store = DataStoreService:GetDataStore("Bios")

local function limitText(text, maxLength)
	if typeof(text) ~= "string" or #text > maxLength then
		return ""
	end
	return text
end

local function l5(text, maxLength) return limitText(text, maxLength) end
local function l4(text, maxLength) return l5(text, maxLength) end
local function l3(text, maxLength) return l4(text, maxLength) end
local function l2(text, maxLength) return l3(text, maxLength) end
local function l1(text, maxLength) return l2(text, maxLength) end

ReplicatedStorage.Remotes.SetBio.OnServerEvent:Connect(function(player, request) -- expect: luau-shield007
	if typeof(request) ~= "table" then return end
	local bio = l1(request.bio, request.maxLength)
	store:SetAsync("bio_" .. player.UserId, bio) -- expect: luau-shield001
end)
