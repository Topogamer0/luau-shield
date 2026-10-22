--!strict
-- Item inspector: hovering an item in the world invokes InspectItem with the
-- Instance, and the server answers with a description for the tooltip. The
-- handler accepts ANY Instance from the client, which looks scary, but it
-- only reads it with query methods (IsA, GetAttribute, FindFirstChild,
-- GetChildren, GetFullName) and string methods, and never modifies,
-- destroys, moves or rewards anything with it. Nothing for luau-shield003 to report.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InspectItem = ReplicatedStorage.Remotes.InspectItem :: RemoteFunction

export type ItemInfo = {
	name: string,
	rarity: string,
	description: string,
	parts: number,
}

local RARITY_NAMES: { [number]: string } = { "Common", "Rare", "Epic", "Legendary" }

InspectItem.OnServerInvoke = function(player: Player, item: Instance): ItemInfo?
	if typeof(item) ~= "Instance" or not item:IsA("Model") then
		return nil
	end

	local rarity = item:GetAttribute("Rarity")
	local descriptionValue = item:FindFirstChild("Description")
	local description = if descriptionValue and descriptionValue:IsA("StringValue") then descriptionValue.Value else ""

	return {
		name = item.Name:upper(),
		rarity = if typeof(rarity) == "number" then RARITY_NAMES[rarity] or "Unknown" else "Unknown",
		description = description:sub(1, 200),
		parts = #item:GetChildren(),
	}
end
