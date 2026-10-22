--!strict
-- Furniture editor: the client drags a piece of furniture around its plot and
-- invokes MoveFurniture with the final CFrame. The furniture is looked up on
-- the server inside the player's own plot; only the CFrame comes from the
-- client.
--
-- Exploit: invoke with a CFrame inside another player's base, on top of the
-- spawn or across the only corridor of the map: the server moves the
-- anchored, collidable furniture there and griefs everybody.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MoveFurniture = ReplicatedStorage.Remotes.MoveFurniture :: RemoteFunction

MoveFurniture.OnServerInvoke = function(player: Player, furnitureId: string, target: CFrame): boolean
	local plot = workspace.Plots:FindFirstChild(player.Name)
	if not plot then
		return false
	end

	local model = plot.Furniture:FindFirstChild(furnitureId)
	if not model or not model:IsA("Model") or typeof(target) ~= "CFrame" then
		return false
	end

	model:PivotTo(target) -- expect: luau-shield002
	return true
end
