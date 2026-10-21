# Expected findings: vulnerable-game

`luau-shield check examples/vulnerable-game` should report exactly the
**27 findings** below (exit code 1). Paths are relative to
`examples/vulnerable-game/`. The same game with every hole fixed,
`examples/fixed-game/`, should report **no findings** (exit code 0).

Findings inside server modules (`src/server/Modules/*`) are reported at the
sink line in the module: the analyzer follows the `require` and the call from
the remote handler. A sink line reached by several handlers is reported once.

| File | Line | Rule | Explanation |
| --- | --- | --- | --- |
| `src/server/AdminConsole.server.luau` | 23 | LS004 | `loadstring(source)` runs code sent through the `AdminCommand` remote; the only check is a password that ships to every client in `Config` (see `src/shared/Config.luau:46`). |
| `src/server/AdminConsole.server.luau` | 39 | LS004 | `require(tonumber(argument))` loads an asset id typed in chat (`player.Chatted`); `isAdmin` checks the player, not the id, so any public module (or a backdoor) can be loaded. |
| `src/server/CombatService.server.luau` | 30 | LS003 | `target:TakeDamage(...)` on a client-sent Humanoid that is only type-checked (`typeof` + `IsA`), with no range or location check: hit any player anywhere on the map. |
| `src/server/CombatService.server.luau` | 30 | LS002 | `TakeDamage(damage)` with the client's `damage` (`math.huge` one-shots everyone, negative values heal). |
| `src/server/CombatService.server.luau` | 36 | LS002 | `humanoid.WalkSpeed = speed` with the client's `speed` (speed hack). |
| `src/server/CombatService.server.luau` | 48 | LS002 | `root.CFrame` set from the client's `targetPosition` without a distance check (teleport anywhere; the cooldown limits frequency, not distance). |
| `src/server/LobbyService.server.luau` | 15 | LS007 | `LaunchFirework` does `Instance.new("Part")` and `:Clone()` (line 28) with no rate limit: part spam lags the server. |
| `src/server/LobbyService.server.luau` | 33 | LS007 | `SubmitBugReport` calls `Analytics.reportBug`, which does `HttpService:PostAsync`, with no rate limit (exhausts the HTTP budget, gets the webhook rate-limited). |
| `src/server/LobbyService.server.luau` | 37 | LS007 | `TrackEvent` calls `Analytics.track`, which does `HttpService:PostAsync`, with no rate limit. |
| `src/server/Modules/Analytics.luau` | 19 | LS005 | `PostAsync` URL contains the client's `eventName` (path traversal on the analytics API, with the API key appended) and the body contains the client's `properties` table; reached from `TrackEvent` (`LobbyService.server.luau:37`). |
| `src/server/Modules/Analytics.luau` | 26 | LS005 | Bug report body contains the client's `category` and `text` unfiltered and without a length limit (`@everyone` pings, slurs, oversized payloads posted to the team's webhook); reached from `SubmitBugReport` (`LobbyService.server.luau:33`). |
| `src/server/Modules/DataManager.luau` | 74 | LS001 | `profile[key] = value` with keys and values from the client's settings table: mass assignment, `{ Coins = 1e12, Inventory = {...} }` overwrites the saved profile; reached from `SaveSettings` (`PlayerData.server.luau:47`). |
| `src/server/Modules/DataManager.luau` | 76 | LS001 | The client's table is written as is to the `Settings_v1` DataStore with `SetAsync` (arbitrary or oversized data in persistent storage). |
| `src/server/Modules/Economy.luau` | 18 | LS001 | `profile.Coins += amount` with the client's `coins` from `OfferTrade` (`TradeService.server.luau:29`): `getCoins(player) < coins` is only an upper bound, so negative amounts and NaN pass. |
| `src/server/Modules/Economy.luau` | 21 | LS001 | Same client value added to `leaderstats.Coins.Value`. |
| `src/server/Modules/Economy.luau` | 31 | LS001 | `profile.Coins -= cost` with the client's `price` (`BuyItem`, `ShopService.server.luau:40`) or `coins` (`OfferTrade`, `TradeService.server.luau:28`): `profile.Coins < cost` is only an upper bound, so a negative price adds coins and NaN corrupts the balance. |
| `src/server/Modules/Economy.luau` | 34 | LS001 | Same client value subtracted from `leaderstats.Coins.Value`. |
| `src/server/PlayerData.server.luau` | 47 | LS007 | `SaveSettings` reaches `settingsStore:SetAsync` (`DataManager.luau:76`) on every click with no rate limit (DataStore throttling for the whole server). |
| `src/server/PlotService.server.luau` | 43 | LS007 | `PlaceObject` clones furniture (`template:Clone()`, line 56) with no rate limit. |
| `src/server/PlotService.server.luau` | 57 | LS002 | `object:PivotTo(cframe)` with the client's CFrame: furniture placed outside the player's plot, inside other plots, or at NaN. |
| `src/server/PlotService.server.luau` | 69 | LS003 | `object:Destroy()` on a client-sent Model that is only type-checked (`IsA("Model")`); no `OwnerId` / plot check, so any model (other players' furniture, the map) can be deleted. |
| `src/server/ShopService.server.luau` | 35 | LS007 | `BuyItem` reaches `template:Clone()` in `giveTool` (line 17) with no rate limit. |
| `src/server/ShopService.server.luau` | 43 | LS001 | `profile.Inventory[itemId] = true` with a client-chosen key: any string, including items that are not for sale, is added to the saved inventory. |
| `src/server/TradeService.server.luau` | 22 | LS006 | `ConfirmTrade:InvokeClient(...)` in a server handler: if the receiver (or an exploit) never answers, the thread yields forever and the receiver stays `busy`; the answer itself is client-controlled. |
| `src/shared/Config.luau` | 44 | LS008 | Analytics API key (`AnalyticsApiKey`) hard-coded in a ModuleScript replicated to every client. |
| `src/shared/Config.luau` | 45 | LS008 | Discord webhook URL in replicated code: anyone can post to the team's channel or delete the webhook. |
| `src/shared/Config.luau` | 46 | LS008 | Developer console password (`AdminPassword`) in replicated code; it unlocks the `loadstring` console (LS004 above). |

## Count per rule

| Rule | Findings |
| --- | --- |
| LS001 untrusted-economy-write | 7 |
| LS002 untrusted-instance-property | 4 |
| LS003 unverified-client-instance | 2 |
| LS004 untrusted-code-execution | 2 |
| LS005 untrusted-http-request | 2 |
| LS006 server-invokes-client | 1 |
| LS007 remote-without-rate-limit | 6 |
| LS008 client-exposed-secret | 3 |
| **Total** | **27** |

## Deliberately not reported

These lines look close to a sink but must **not** produce a finding:

- `src/client/*.client.luau`: server-side rules never run on LocalScripts.
  `ConfirmTrade.OnClientInvoke` (`HudController.client.luau:55`) is the client
  half of the LS006 finding and is not reported; the client scripts read
  `Config.AdminPassword` but contain no secret literal (no LS008).
- `src/server/PlayerData.server.luau:19`: `coins.Value = profile.Coins` writes
  a value loaded from the DataStore (server data).
- `src/server/Modules/Remotes.luau` and `PlayerData.server.luau:14,17`:
  `Instance.new` outside remote handlers (no LS007).
- `src/server/Modules/DataManager.luau:53`: `SetAsync` of server data, called
  from `PlayerRemoving`, `BindToClose` and the autosave loop, not from a
  remote handler.
- `src/server/ShopService.server.luau:28`: `giveTool` from `CharacterAdded`
  (not a remote handler). Line 37 reads the inventory with the client key;
  it is a read, and the guard returns when the item is owned, so it does not
  allow-list `itemId`.
- `src/server/PlotService.server.luau:46`: the `profile.Inventory[itemId]`
  guard allow-lists `itemId`, and `furniture:FindFirstChild(itemId)` is a
  server lookup, so the cloned object, `SetAttribute("OwnerId", ...)` and
  `profile.PlotObjects += 1` only involve server values.
- `src/server/LobbyService.server.luau:18`: `effects:FindFirstChild(effectName)`
  is a server lookup; the rocket and the effect are server instances, so the
  `CFrame` / `Parent` writes and `Debris:AddItem` are not LS002/LS003.
- `src/server/CombatService.server.luau:43-47`: Blink has a cooldown
  (`os.clock`), but it does no expensive work, so there is no LS007 either
  way; the cooldown does not sanitize the position (LS002 on line 48).
- `src/server/TradeService.server.luau:24`: the value returned by
  `InvokeClient` is client-controlled but only compared with `true`.
- `src/shared/Config.luau:43`: `AnalyticsUrl` is a plain URL, not a secret.
