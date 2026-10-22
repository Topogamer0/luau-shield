-- Pet renaming: the player types a name for their pet and the server shows it
-- in a BillboardGui above the pet, visible to everybody in the server.
-- A type and length check is not text filtering: every user-generated text
-- shown to other users must go through TextService first.
--
-- Exploit: name the pet with slurs, personal information or a scam link; it
-- is displayed unfiltered to every player (and gets the game moderated).
-- Also luau-shield007: the handler clones a GUI on every request with no rate limit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local RenamePet = ReplicatedStorage.Remotes.RenamePet :: RemoteEvent
local NameTagTemplate = ServerStorage.UI.PetNameTag :: BillboardGui

local MAX_NAME_LENGTH = 20

RenamePet.OnServerEvent:Connect(function(player: Player, name: string) -- expect: luau-shield007
	if typeof(name) ~= "string" or #name == 0 or #name > MAX_NAME_LENGTH then
		return
	end

	local pet = workspace.Pets:FindFirstChild(player.Name)
	if not pet or not pet:IsA("Model") then
		return
	end

	local oldTag = pet:FindFirstChild("PetNameTag")
	if oldTag then
		oldTag:Destroy()
	end

	local tag = NameTagTemplate:Clone()
	local label = tag:FindFirstChild("NameLabel") :: TextLabel
	label.Text = name -- expect: luau-shield002
	tag.Adornee = pet.PrimaryPart
	tag.Parent = pet
end)
