--!strict
-- Game configuration shared by the server scripts and the client UI.
-- This ModuleScript lives in ReplicatedStorage, so its source is downloaded
-- by every client that joins the game: it must never contain secrets.
-- Webhook URLs and API keys are experience secrets read on the server with
-- HttpService:GetSecret (see ServerScriptService.Server.Modules.Analytics).

export type Item = {
	DisplayName: string,
	Price: number,
	Placeable: boolean,
}

local Config = {}

-- Economy
Config.StartingCoins = 100
Config.MaxTradeCoins = 100_000
Config.PurchaseCooldown = 0.5
Config.Items = {
	Sword = { DisplayName = "Classic Sword", Price = 150, Placeable = false },
	Conveyor = { DisplayName = "Conveyor", Price = 100, Placeable = true },
	Dropper = { DisplayName = "Coin Dropper", Price = 250, Placeable = true },
	Lamp = { DisplayName = "Neon Lamp", Price = 60, Placeable = true },
	Fountain = { DisplayName = "Golden Fountain", Price = 5000, Placeable = true },
} :: { [string]: Item }

-- Combat and movement
Config.WalkSpeed = 16
Config.SprintSpeed = 24
Config.SwordDamage = 20
Config.SwordRange = 8
Config.SwordCooldown = 0.6
Config.BlinkDistance = 30
Config.BlinkCooldown = 3

-- Plots
Config.PlotRadius = 40
Config.MaxPlotObjects = 50
Config.PlaceCooldown = 0.25

-- Lobby
Config.Fireworks = { "Rocket", "Sparkler", "Confetti" }
Config.FireworkLifetime = 5
Config.BugCategories = { "Gameplay", "Shop", "Trading", "Other" }
Config.BugReportMaxLength = 500
Config.AnalyticsEvents = { "shop_opened", "bug_report_sent", "trade_offered" }

return Config
