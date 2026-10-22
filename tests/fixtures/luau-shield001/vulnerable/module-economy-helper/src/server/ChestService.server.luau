-- Vulnerable (caller side): treasure chests are opened by a client-side
-- animation, which then reports how many coins were inside. The handler hands
-- that number to Economy.addCoins, which writes it to leaderstats. The finding
-- is reported in Economy.luau, on the write.
--
-- Exploit: fire ChestOpened with ("GoldChest", 1e9).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(script.Parent.Economy)

local ChestOpened = ReplicatedStorage.Remotes.ChestOpened :: RemoteEvent

local opened: { [Player]: { [string]: boolean } } = {}

ChestOpened.OnServerEvent:Connect(function(player: Player, chestId: string, coins: number)
	local openedByPlayer = opened[player] or {}
	if openedByPlayer[chestId] then
		return
	end
	openedByPlayer[chestId] = true
	opened[player] = openedByPlayer

	Economy.addCoins(player, coins)
end)
