--!strict
-- Housing game, fixed: the model must pass Validate.isOwnedFurniture (a
-- shared module that compares the model's "Owner" attribute with the
-- player's UserId) before Furniture.pickUp moves it. Furniture from other
-- players' houses is rejected.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Furniture = require(script.Parent.Furniture)
local Validate = require(ReplicatedStorage.Shared.Validate)

local PickUpFurniture = ReplicatedStorage.Remotes.PickUpFurniture :: RemoteEvent

PickUpFurniture.OnServerEvent:Connect(function(player: Player, model: Model)
	if not Validate.isOwnedFurniture(model, player) then
		warn(`{player.Name} tried to pick up furniture they do not own`)
		return
	end
	Furniture.pickUp(player, model)
end)
