# Changelog

All notable changes to luau-shield are documented in this file. The format is
based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the
project follows [Semantic Versioning](https://semver.org/).

## [0.2.0] - 2026-10-22

This release fixes the false positives reported after running v0.1.0 on a
real 144-file game (5 warnings, all false positives), without losing any
vulnerable case of the test corpus. Two adversarial reviews of the fixes
found 54 and then 43 problems in earlier versions of these changes (mostly
false negatives they introduced); all of them are fixed or documented below,
and each fixed case is now a corpus fixture.

### Added

- **`info` severity**, below `low`. It is used for findings that are only
  reachable by admins (see below) and is hidden at the default
  `min-severity = "low"`; use `--min-severity info` to see them. `info` is
  accepted by `--min-severity`, `--fail-on`, `min-severity`, `fail-on` and
  `[rules]` severities, is counted in the summary, and is written as SARIF
  level `note`.
- **Permission guards** (`[guards]` in `luau-shield.toml`). Code that only runs
  after a permission check on the player who sent the request is reported as
  `info` with "(admin only: after ...)" in the message:
  - guard functions: `isAdmin`, `isModerator`, `isStaff`, `isDeveloper`,
    `isCreator`, `isGameOwner`, `hasPermission` and similar names, called
    directly or on a module named like a permission module (`Admins`,
    `PermissionService`, `Ranks`...), with the sender (`player`,
    `player.UserId`, `player.Name`) and constants as arguments; your own with
    `[guards] functions`; the built-in names can be turned off with
    `[guards] defaults = false`;
  - `self:isAdmin(player)` inside a service (named after the table the
    method is declared on), and Knit's `self.Server:isAdmin(player)`;
  - permission levels compared with a server value
    (`Admin.getLevel(player) >= 2`, `getRank(player) < command.rank`) for
    the functions in `[guards] functions`;
  - inline checks: `player.UserId == game.CreatorId` (or a constant id);
    `player:GetRankInGroup(GROUP) >= N` with a constant group and a lowest
    passing rank of at least 2 (also `> N`, `== N`, `< N` / `~= N` to
    reject, and through a local); `player:GetRoleInGroup(GROUP) == "Admin"`;
    `ADMINS[player.UserId]` and `table.find(ADMIN_IDS, player.UserId)` (also
    through a local or compared with `nil`) with a server table named like
    `admin`, `moder`, `staff` or `developer`;
  - a `player.Chatted` listener connected only after such a check on that
    player, and the handler's own `...` arguments read after it, are
    admin-only too.

  Not guards: checks on a player or object chosen by the client, on
  `player.DisplayName`, on another object (`isOwner(player, plot)`,
  `plot:hasPermission(player, "Build")`), on a module or list picked with a
  client key (`ClanRoles[clanId]:isModerator(player)`,
  `clanAdmins[clanId][player.UserId]`), on tables of owners (plots,
  tycoons, game passes) or whitelists (beta testers), on a list that a
  remote handler fills with client data, group membership
  (`GetRankInGroup(G) >= 1`, `> 0`, `>= 0`) or a group or rank sent by the
  client, and comparisons that also hold for `false` or `nil`
  (`isAdmin(player) ~= nil`, `isAdmin(player) == false`). The inline checks
  follow `[guards] defaults`. Never downgraded: code execution
  (luau-shield004) and unfiltered text shown to other players
  (luau-shield002 on `Text`). A function, callback or listener reached from
  an admin handler and from a public one is analysed for both.
- **Sanitizer hints.** When the value of a finding comes out of a function
  named like a sanitizer (`Look.sanitize`, `validateLook`, `clampIndex`...)
  that luau-shield could not follow, or that makes some but not all of the
  required checks, the fix suggests declaring it in `[[sanitizers]]`, under
  the name used at the call site. Functions that only convert or clean text
  (no bounds, NaN, length or allow-list check) get no hint.
- `CHANGELOG.md`.

### Changed

- **Loops that copy by key run once per field** (luau-shield001).
  `for key, value in patch do changed[key] = value end`, where `patch` is a
  table built by the server such as `{ coins = amount }`, no longer makes
  every field of `changed` (`changed.level`, `changed.xp`) carry `amount`.
  Only loops that write `t[key] = ...` and create no functions are run per
  field (at most 16 fields, two nested loops); tables sent by the client
  still taint every field.
- **Digits-only patterns reject NaN** (luau-shield001).
  `tonumber(string.match(text, "(%-?%d+)"))` can never be NaN, so with bounds
  (`math.clamp`) the number is fully checked.
- **Calls too deep to follow use a return summary** (value rules). When a
  call is beyond `max-call-depth`, luau-shield analyses the function once
  with placeholder arguments (`self` included) and reuses what it returns,
  with the checks it made. A sanitizer that builds a new table field by field
  (`Look.sanitize(raw)` returning `{ hair = clampIndex(raw.hair, 10, 1), ...
  }`) now protects its result at the end of a long call chain. Validators
  used as guards (`if not Validate.amount(x) then return end`) also count
  past the depth limit. Bounds, length limits and allow-lists that come
  from another argument (`inRange(amount, 1, claimedBalance)`,
  `math.clamp(v, 0, max)`) only count when that argument is server data,
  also for shallow guards. A function that returns one of its parameters
  unchanged is assumed to have stored the other arguments in it; closures
  it returns keep the values they captured; a function that yields yields
  at the call. Summaries are bounded (half the call depth, a global budget)
  and are made again when the handler stored client data in module state,
  so large projects stay fast (faster than v0.1.0 on generated games with
  large item catalogs).
- **State machines limit a remote** (luau-shield007). A handler that tests a
  state and changes it before the expensive work, so that the same test fails
  on the next request, is not reported: `if state[player] ~= "Playing" then
  return end; state[player] = "Menu"; store:UpdateAsync(...)`, or
  `if data[p].Slots[s] then data[p].Slots[s] = nil; store:UpdateAsync(...)
  end` in a helper. Named constants, a local copy of the state for the test,
  a local holding the player's entry (`local profile = Profiles[player]`),
  attributes, and lists (`table.find` with `table.insert` or
  `table.remove`) are recognised; work wrapped in `pcall` followed by a
  reset is fine. It does not count when the state is put back before the
  handler waits (also when the only wait is on another path, after a
  cleanup scheduled with `task.delay`, or on the next `Heartbeat`), when
  another path of the handler writes a value that passes the test again (a
  toggle, also with an early return or two `if`s; join and leave on one
  remote), when it is changed after a yield (also `x or Event:Wait()`,
  Promise `:await()`, `BindableFunction:Invoke()`, `coroutine.yield()` and
  yields in deep functions) or only in a `task.delay`, `task.defer` or
  `:andThen` function, when a copy read before a yield is tested after it,
  when its key or table is chosen by the client or created by the request,
  when only a local copy or another player's state is changed, or when the
  wait is shorter than 0.1 s or chosen by the client.
- **Conditional work is described as such** (luau-shield007). When all the
  expensive calls of a handler run inside an `if` (and not on the other
  branch), the message says the handler calls them "when a condition [in
  `function`] holds" and asks to check that a client cannot make it hold on
  every request, instead of "on every request". The severity is unchanged.
- **A handler's own code always runs**, even when the analysis budget is
  spent in deep calls, so its sinks are not dropped.

### Fixed

- The four false-positive patterns of the report, each covered by a safe
  fixture (no warning) and by vulnerable variants that are still reported.
- `data[name].Value += gems` with `name` holding a constant (`"Gems"`) was not
  recognised as a currency write.
- Conditions stored in a table returned by a function
  (`return { price = priceOk }`) no longer validate unrelated variables of
  the caller.
- A downgraded (admin-only) luau-shield003 finding no longer hides a later
  exploitable one on the same Instance, and admin-only luau-shield003
  findings are reported once per Instance instead of once per use.
- Admin-only messages name both guards of `isAdmin(p) or isModerator(p)`,
  show inline checks in the form that passes (`player.UserId ==
  game.CreatorId` for `if player.UserId ~= game.CreatorId then return end`),
  and admin-only luau-shield007 findings get a fix about flooding, not about
  values.
- A table built by the request and filled by a helper
  (`TableUtil.assign({ Coins = 0 }, { Gems = amount })` returned to the
  client) is no longer reported as a currency write; what a helper stores in
  a table it receives is now visible to the caller.
- Handler tables with more than 16 functions connected in a loop: every
  handler is analysed (up to 64).

## [0.1.0] - 2026-10-22

First release.

- Taint analysis of Roblox Luau server code with full-moon: sources (remote
  handlers, `Player.Chatted`, Knit client methods, custom sources),
  propagation through variables, tables, local functions and resolved
  `require`s (Rojo projects, `script.Parent`, string requires, `.luaurc`
  aliases), and recognition of checks (types, bounds, NaN, allow-lists,
  patterns, lengths, ownership, validation functions, the `t` library).
- Rules luau-shield001 to luau-shield008.
- Text, JSON and SARIF output, exit codes, `luau-shield.toml`
  configuration, inline suppressions, optional `--explain` through a local
  Ollama.
- GitHub Action with SARIF upload, release binaries for Windows, macOS and
  Linux, installation with Rokit.

[0.2.0]: https://github.com/Topogamer0/luau-shield/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Topogamer0/luau-shield/releases/tag/v0.1.0
