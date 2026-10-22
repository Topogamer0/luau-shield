--!strict
-- Thin client for the studio's backend (same module as in the vulnerable
-- profile-lookup-backend-module entry). Callers are expected to pass values
-- that are safe to put in a URL; the module does not check them itself.

local HttpService = game:GetService("HttpService")

local BASE_URL = "https://api.example-studio.dev/v3"
local HEADERS = {
	Authorization = HttpService:GetSecret("backend_api_key"):AddPrefix("Bearer "),
}

export type Profile = {
	userId: number,
	displayName: string,
	guild: string?,
	badges: { string },
}

local Backend = {}

-- Returns nil when the request fails (unknown player, backend down).
function Backend.fetchProfile(username: string): Profile?
	local ok, response = pcall(function()
		return HttpService:GetAsync(`{BASE_URL}/profiles/{username}`, false, HEADERS)
	end)
	return if ok then HttpService:JSONDecode(response) else nil
end

function Backend.fetchProfileById(userId: number): Profile?
	local ok, response = pcall(function()
		return HttpService:GetAsync(`{BASE_URL}/profiles/by-id/{userId}`, false, HEADERS)
	end)
	return if ok then HttpService:JSONDecode(response) else nil
end

return Backend
