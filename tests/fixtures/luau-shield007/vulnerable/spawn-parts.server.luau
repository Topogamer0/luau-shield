-- Vulnerable: every firework request creates parts on the server. Thousands
-- of requests per second lag or crash the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

ReplicatedStorage.Remotes.Firework.OnServerEvent:Connect(function(player: Player) -- expect: luau-shield007
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local spark = Instance.new("Part")
	spark.Size = Vector3.new(1, 1, 1)
	spark.Anchored = true
	spark.CFrame = root.CFrame * CFrame.new(0, 10, 0)
	spark.Parent = workspace
	Debris:AddItem(spark, 3)
end)
