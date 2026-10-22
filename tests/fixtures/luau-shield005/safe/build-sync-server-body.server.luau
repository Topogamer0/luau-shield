--!strict
-- Safe: plot backups through a Knit service (twin of the vulnerable
-- build-sync-client-method-body entry). The client says what it wants
-- ("save" or "delete"), and the server picks the HTTP method from its own
-- table. The body is built on the server from the player's plot; the only
-- client value in it is the build name, a string of at most 32 characters.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local BUILDS_API = "https://builds.example-studio.dev/v1"
local API_KEY = HttpService:GetSecret("builds_api_key")
local SYNC_COOLDOWN = 10
local MAX_NAME_LENGTH = 32

local METHODS: { [string]: string } = { save = "PUT", delete = "DELETE" }

local BuildSyncService = Knit.CreateService({
	Name = "BuildSyncService",
	Client = {},
	lastSync = {} :: { [Player]: number },
})

function BuildSyncService:checkCooldown(player: Player): boolean
	local now = os.clock()
	if now - (self.lastSync[player] or 0) < SYNC_COOLDOWN then
		return false
	end
	self.lastSync[player] = now
	return true
end

local function serializePlot(player: Player): { { string | number } }
	local blocks = {}
	local plot = workspace.Plots:FindFirstChild(tostring(player.UserId))
	for _, part in if plot then plot:GetChildren() else {} do
		if part:IsA("BasePart") then
			table.insert(blocks, { part.Name, part.Position.X, part.Position.Y, part.Position.Z })
		end
	end
	return blocks
end

function BuildSyncService.Client:Sync(player: Player, action: string, buildName: string): boolean
	if not self.Server:checkCooldown(player) then
		return false
	end
	local method = METHODS[action]
	if not method or typeof(buildName) ~= "string" or #buildName > MAX_NAME_LENGTH then
		return false
	end

	local request = {
		Url = `{BUILDS_API}/users/{player.UserId}/builds`,
		Method = method,
		Headers = { ["Content-Type"] = "application/json", ["X-Api-Key"] = API_KEY },
		Body = HttpService:JSONEncode({ name = buildName, blocks = serializePlot(player) }),
	}
	local response = HttpService:RequestAsync(request)
	return response.Success
end

Knit.Start():catch(warn)
