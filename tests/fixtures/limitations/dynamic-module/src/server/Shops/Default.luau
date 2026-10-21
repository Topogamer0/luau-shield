local Default = {}

function Default.charge(player: Player, price: number)
	player.leaderstats.Coins.Value -= price -- expect: LS001
end

return Default
