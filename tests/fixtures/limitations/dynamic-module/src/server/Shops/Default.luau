local Default = {}

function Default.charge(player: Player, price: number)
	player.leaderstats.Coins.Value -= price -- expect: luau-shield001
end

return Default
