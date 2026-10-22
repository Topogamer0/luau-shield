--!strict
-- Game configuration shared by the server scripts and the client UI.
-- This ModuleScript lives in ReplicatedStorage, so its source is downloaded
-- by every client that joins the game.

export type Item = {
	DisplayName: string,
	Price: number,
	Placeable: boolean,
}

local Config = {}

-- Economy
Config.StartingCoins = 100
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
Config.BlinkDistance = 30
Config.BlinkCooldown = 3

-- Plots
Config.PlotRadius = 40
Config.MaxPlotObjects = 50

-- Lobby
Config.Fireworks = { "Rocket", "Sparkler", "Confetti" }
Config.FireworkLifetime = 5
Config.BugCategories = { "Gameplay", "Shop", "Trading", "Other" }

-- Integrations: analytics backend, bug report channel and the password of
-- the developer console.
Config.AnalyticsUrl = "https://analytics.tycoonshop.example/v1"
Config.AnalyticsApiKey = "tsk_live_4f9a2c7e1b8d3f6a0c5e9b2d7a4f1c8e"
Config.BugReportWebhook = "https://discord.com/api/webhooks/1187362049571234816/qT7vXz2LmN9pRk4sYw8aBcDe5fGh1jK0lMnOpQrStUvWxYz3AbCdEfGhIjKlMnOp6Q"
Config.AdminPassword = "Tyc00n-Adm1n-2024!"

return Config
