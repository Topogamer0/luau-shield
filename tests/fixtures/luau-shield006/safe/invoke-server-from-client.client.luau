-- Safe: InvokeServer from a LocalScript is the intended direction.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetCoins = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GetCoins") :: RemoteFunction

local coins = GetCoins:InvokeServer()
print("coins:", coins)
