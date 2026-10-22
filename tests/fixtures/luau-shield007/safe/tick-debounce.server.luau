-- Safe: an older but working debounce based on tick().
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local lastFirework = {}

ReplicatedStorage.Remotes.Firework.OnServerEvent:Connect(function(player)
	if lastFirework[player.UserId] and tick() - lastFirework[player.UserId] < 2 then
		return
	end
	lastFirework[player.UserId] = tick()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local spark = Instance.new("Part")
	spark.Anchored = true
	spark.CFrame = root.CFrame * CFrame.new(0, 10, 0)
	spark.Parent = workspace
	Debris:AddItem(spark, 3)
end)
