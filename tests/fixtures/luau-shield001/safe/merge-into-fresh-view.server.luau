-- Safe (v0.2.0 review): a merge helper fills a view table built for the reply.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local function merge(into, from)
	for key, value in from do
		into[key] = value
	end
end
ReplicatedStorage.Remotes.Preview.OnServerInvoke = function(player, amount)
	local view = { Coins = 0, Gems = 0 }
	merge(view, { Gems = amount })
	return view
end
