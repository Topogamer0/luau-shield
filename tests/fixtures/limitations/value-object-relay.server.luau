-- Limitation: values stored in Instances (ValueBase objects, attributes) and
-- read back later are not followed. The client's speed is stored in a
-- NumberValue, then applied by a Changed listener: the WalkSpeed write should
-- be reported, but the flow through the Instance is lost (false negative).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage.Remotes.SetSpeed.OnServerEvent:Connect(function(player: Player, speed: number)
	local setting = player:FindFirstChild("SpeedSetting") :: NumberValue
	setting.Value = speed
end)

game:GetService("Players").PlayerAdded:Connect(function(player: Player)
	local setting = Instance.new("NumberValue")
	setting.Name = "SpeedSetting"
	setting.Parent = player
	setting.Changed:Connect(function(value: number)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = value -- expect: LS002
		end
	end)
end)
