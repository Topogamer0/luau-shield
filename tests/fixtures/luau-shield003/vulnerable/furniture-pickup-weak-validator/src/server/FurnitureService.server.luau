--!strict
-- Housing game: in edit mode the client fires PickUpFurniture with the model
-- under the mouse. The handler checks it with Validate.isFurniture (a shared
-- module) and hands it to Furniture.pickUp (a server module), which moves it
-- into the player's inventory folder.
--
-- Exploit: fire PickUpFurniture with the furniture of OTHER players' houses.
-- Every model passes isFurniture, so it is moved into the exploiter's
-- inventory and saved as theirs: the whole server's furniture can be stolen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Furniture = require(script.Parent.Furniture)
local Validate = require(ReplicatedStorage.Shared.Validate)

local PickUpFurniture = ReplicatedStorage.Remotes.PickUpFurniture :: RemoteEvent

PickUpFurniture.OnServerEvent:Connect(function(player: Player, model: Model)
	if not Validate.isFurniture(model) then
		warn(`{player.Name} tried to pick up something that is not furniture`)
		return
	end
	Furniture.pickUp(player, model)
end)
