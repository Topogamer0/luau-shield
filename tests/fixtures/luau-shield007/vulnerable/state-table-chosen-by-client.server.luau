-- Vulnerable (v0.2.0 review): the state table is picked with a key the client chooses, through a local.
-- Promo codes: for each code (chosen by the client), a table of who used
-- it. The per-code table is fetched into a local first. The test and the
-- change are on `uses[player]`, keyed by the sender, but `uses` itself is
-- picked by the client: every new code string gives a new, empty table, so
-- every request with a fresh code passes and does the DataStore lookup.
-- Writing `codeUses[code][player]` directly is reported.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local codesStore = DataStoreService:GetDataStore("PromoCodes")
local Redeem = ReplicatedStorage.Remotes.RedeemCode
local codeUses: { [string]: { [Player]: string } } = {}

Redeem.OnServerEvent:Connect(function(player: Player, code: unknown) -- expect: luau-shield007
	if typeof(code) ~= "string" or #code > 20 then
		return
	end
	local uses = codeUses[code]
	if not uses then
		uses = {}
		codeUses[code] = uses
	end
	if uses[player] == "Redeemed" then
		return
	end
	uses[player] = "Redeemed"
	local ok, reward = pcall(codesStore.GetAsync, codesStore, code)
	if ok and reward then
		print(player.Name, "redeemed", code)
	end
end)
