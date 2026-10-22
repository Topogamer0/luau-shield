# Examples

Two versions of the same small Roblox game, **Tycoon Shop**, written as Rojo
projects:

| Directory | Contents | Expected result |
| --- | --- | --- |
| [`vulnerable-game/`](vulnerable-game/) | The game as many games are written: it works, but trusts the client in the ways exploiters abuse. | 27 findings, at least one of every rule (luau-shield001 to luau-shield008); the full list with exact lines is in [`vulnerable-game/EXPECTED.md`](vulnerable-game/EXPECTED.md). Exit code 1. |
| [`fixed-game/`](fixed-game/) | The same game with every hole fixed the way a careful Roblox developer would fix it. | No findings. Exit code 0. |

The games are complete at the script level but do not ship the place assets
they reference (the `HUD` and `Shop` ScreenGuis, `ServerStorage.Tools`,
`ServerStorage.Furniture`, `ServerStorage.Effects` and the `Workspace.Plots`
models), so they are meant to be read and analysed, not played as they are.
All the secrets in `vulnerable-game/src/shared/Config.luau` are fake.

## Running luau-shield

From the repository root:

```sh
luau-shield check examples/vulnerable-game    # 27 findings, exit code 1
luau-shield check examples/fixed-game         # no findings, exit code 0
```

Each example has a `default.project.json` at its root, which tells luau-shield
where every file runs (server, client or replicated). You can also pass it
explicitly:

```sh
luau-shield check examples/vulnerable-game --project examples/vulnerable-game/default.project.json
```

Other useful variations:

```sh
luau-shield check examples/vulnerable-game -s high                    # only high and critical
luau-shield check examples/vulnerable-game --only luau-shield003      # a single rule
luau-shield check examples/vulnerable-game --format sarif -o results.sarif
luau-shield check examples/vulnerable-game --format json -o findings.json
```

## The game

```
default.project.json         ServerScriptService.Server   -> src/server
                             ReplicatedStorage.Shared     -> src/shared
                             StarterPlayer.StarterPlayerScripts -> src/client
src/server/
  Modules/Remotes.luau       creates ReplicatedStorage.Remotes at runtime
  Modules/DataManager.luau   DataStore profiles (coins, inventory, settings)
  Modules/Economy.luau       coin helpers used by the shop, trades and admins
  Modules/Analytics.luau     analytics events and bug reports over HTTP
  PlayerData.server.luau     profiles, leaderstats, autosave, settings menu
  ShopService.server.luau    buying items, giving tools
  CombatService.server.luau  sword, sprint, blink
  PlotService.server.luau    placing and removing furniture on your plot
  TradeService.server.luau   coin gifts with a confirmation prompt
  AdminConsole.server.luau   developer console and chat commands
  LobbyService.server.luau   fireworks, bug report board, analytics remote
src/shared/
  Config.luau                game configuration (replicated to clients)
  Validate.luau              validation helpers (fixed version only)
src/client/
  ShopController.client.luau, CombatController.client.luau,
  HudController.client.luau  the legitimate client side of every remote
```

Server scripts require modules both with `require(script.Parent.Modules.X)`
and with `require(ServerScriptService.Server.Modules.X)`, and modules require
each other and the shared `Config` / `Validate` modules, so the examples also
exercise luau-shield's cross-module analysis: several findings of the
vulnerable game are reported inside a module, at the sink reached from a
remote handler in another file.

## Holes and fixes

| Rule | Vulnerable game | Fixed game |
| --- | --- | --- |
| luau-shield001 untrusted-economy-write | `BuyItem` sends the price and the server spends it (a negative price adds coins); coin gifts accept negative / NaN amounts; the settings menu merges the client's table into the profile (`{ Coins = 1e12 }`) and writes it to a DataStore; any client string is added to the inventory. | Prices come from the server's catalog; amounts are checked with `Validate.isIntegerInRange` (type, NaN, lower and upper bound); item ids are allow-listed (`Validate.isItemId`); only known boolean settings are copied and saved with the profile. `Economy` also asserts its inputs. |
| luau-shield002 untrusted-instance-property | The client sends the sword damage, its walk speed, the blink destination and the CFrame of placed furniture. | Damage and speeds are server values (`Sprint` only sends a boolean); blink and placement positions are checked with `Validate.isNearPosition` (Vector3, no NaN, within range of the player / inside the plot); rotations come from a server table. |
| luau-shield003 unverified-client-instance | The server damages any Humanoid the client names and destroys any Model the client sends. | Sword hits are detected on the server (`GetPartBoundsInRadius`); `DeleteObject` only destroys objects whose parent is the player's own plot folder and whose `OwnerId` is the player. |
| luau-shield004 untrusted-code-execution | A "hidden" console runs `loadstring` on code from a remote, protected by a password stored in replicated code; a chat command `require`s any asset id. | No dynamic code: a fixed table of commands (`heal`, `givecoins`, `kick`) dispatched by name, with validated arguments, for user ids listed on the server. |
| luau-shield005 untrusted-http-request | The client chooses the analytics URL path and body; bug report text goes unfiltered to a Discord webhook. | The URL is built on the server from an allow-listed event name passed through `HttpService:UrlEncode`; bug report text is length-limited and filtered with `TextService`, categories are allow-listed, mentions are disabled. |
| luau-shield006 server-invokes-client | Trade confirmation uses `RemoteFunction:InvokeClient`, so the server thread waits for a client that may never answer. | `TradeRequest` / `RespondTrade` RemoteEvents with a pending offer that expires; the server never waits for a client. |
| luau-shield007 remote-without-rate-limit | Fireworks, purchases, furniture placement, settings saves, bug reports and analytics events do `Instance.new`, `:Clone()`, `SetAsync` or `PostAsync` on every call. | Per-player cooldowns based on `os.clock()`; settings are no longer written to a DataStore on each click. |
| luau-shield008 client-exposed-secret | `Config` (in ReplicatedStorage) contains a Discord webhook, an analytics API key and the console password. | Secrets are experience secrets read on the server with `HttpService:GetSecret`; the password is gone (admins are user ids on the server). |
