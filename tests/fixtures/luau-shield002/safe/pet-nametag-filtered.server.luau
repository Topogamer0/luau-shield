-- Pet renaming, fixed: the name goes through TextService (FilterStringAsync
-- + GetNonChatStringForBroadcastAsync, because everybody can see the tag)
-- before it is displayed, and renames are rate limited with os.clock because
-- filtering is a web call and the handler clones a GUI.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TextService = game:GetService("TextService")

local RenamePet = ReplicatedStorage.Remotes.RenamePet :: RemoteEvent
local NameTagTemplate = ServerStorage.UI.PetNameTag :: BillboardGui

local MAX_NAME_LENGTH = 20
local RENAME_COOLDOWN = 5
local lastRename: { [Player]: number } = {}

RenamePet.OnServerEvent:Connect(function(player: Player, name: string)
	local now = os.clock()
	if now - (lastRename[player] or 0) < RENAME_COOLDOWN then
		return
	end
	lastRename[player] = now

	if typeof(name) ~= "string" or #name == 0 or #name > MAX_NAME_LENGTH then
		return
	end

	local pet = workspace.Pets:FindFirstChild(player.Name)
	if not pet or not pet:IsA("Model") then
		return
	end

	-- If the filtering service is down this throws and the rename is dropped.
	local filterResult = TextService:FilterStringAsync(name, player.UserId)
	local filteredName = filterResult:GetNonChatStringForBroadcastAsync()

	local oldTag = pet:FindFirstChild("PetNameTag")
	if oldTag then
		oldTag:Destroy()
	end

	local tag = NameTagTemplate:Clone()
	local label = tag:FindFirstChild("NameLabel") :: TextLabel
	label.Text = filteredName
	tag.Adornee = pet.PrimaryPart
	tag.Parent = pet
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastRename[player] = nil
end)
