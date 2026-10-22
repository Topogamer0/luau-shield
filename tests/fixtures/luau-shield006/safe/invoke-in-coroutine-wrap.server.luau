-- Safe: the invoke runs inside coroutine.wrap, so the main thread continues
-- immediately; the answer is only stored when it is a boolean.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CheckReady = ReplicatedStorage.Remotes.CheckReady :: RemoteFunction

Players.PlayerAdded:Connect(function(player)
	coroutine.wrap(function()
		local ok, ready = pcall(function()
			return CheckReady:InvokeClient(player)
		end)
		if ok and typeof(ready) == "boolean" then
			player:SetAttribute("Ready", ready)
		end
	end)()
end)
