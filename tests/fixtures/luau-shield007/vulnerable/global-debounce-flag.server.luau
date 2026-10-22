-- Vulnerable: one "debounce" flag shared by every player. It only stops two
-- saves from overlapping; it does not limit how often they happen. An
-- exploiter fires SaveBuild again as soon as the previous save returns: the
-- whole DataStore write budget of the server goes to one player, and the flag
-- is busy whenever a real player clicks Save.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local buildStore = DataStoreService:GetDataStore("Builds")
local debounce = false

ReplicatedStorage.Remotes.SaveBuild.OnServerEvent:Connect(function(player) -- expect: luau-shield007
	if debounce then
		return
	end
	debounce = true
	local plot = workspace.Plots:FindFirstChild(player.Name)
	if plot then
		local blocks = {}
		for _, block in plot.Blocks:GetChildren() do
			local position = block.Position
			table.insert(blocks, { block.Name, position.X, position.Y, position.Z })
		end
		pcall(function()
			buildStore:SetAsync(tostring(player.UserId), blocks)
		end)
	end
	debounce = false
end)
