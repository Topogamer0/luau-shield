# Changelog

All notable changes to luau-shield are documented in this file. The format is
based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the
project follows [Semantic Versioning](https://semver.org/).

## [0.2.0] - 2026-10-22

This release fixes the false positives reported after running v0.1.0 on a
real 144-file game (5 warnings, all false positives), without losing any
vulnerable case of the test corpus. An adversarial review of the fixes found
54 problems in the first version of these changes (mostly false negatives
they introduced); all of them are fixed or documented below, and each fixed
case is now a corpus fixture.

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
  - inline checks: `player.UserId == game.CreatorId` (or a constant id),
    `player:GetRankInGroup(GROUP) >= N`, `ADMINS[player.UserId]`,
    `table.find(ADMIN_IDS, player.UserId)`;
  - a `player.Chatted` listener connected only after such a check, and
    `...` arguments read after it, are admin-only too.

  Not guards: checks on a player or object chosen by the client, on
  `player.DisplayName`, on another object (`isOwner(player, plot)`,
  `plot:hasPermission(player, "Build")`), and comparisons that also hold for
  `false` or `nil` (`isAdmin(player) ~= nil`, `isAdmin(player) == false`).
  Never downgraded: code execution (luau-shield004) and unfiltered text shown
  to other players (luau-shield002 on `Text`).
- **Sanitizer hints.** When the value of a finding comes out of a function
  named like a sanitizer (`Look.sanitize`, `validateLook`, `clampIndex`...)
  that luau-shield could not follow, or that makes some but not all of the
  required checks, the fix suggests declaring it in `[[sanitizers]]`, under
  the name used at the call site.
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
  past the depth limit. Summaries are bounded (half the call depth, a global
  budget) so large projects stay fast.
- **State machines limit a remote** (luau-shield007). A handler that tests a
  state and changes it before the expensive work, so that the same test fails
  on the next request, is not reported: `if state[player] ~= "Playing" then
  return end; state[player] = "Menu"; store:UpdateAsync(...)`, or
  `if data[p].Slots[s] then data[p].Slots[s] = nil; store:UpdateAsync(...)
  end` in a helper. Named constants, a local copy of the state for the test,
  and attributes are recognised. It does not count when the state is put
  back before the handler yields, flipped on both branches (a toggle),
  changed only after a yield, keyed by a client-chosen key that starts
  empty, changed only in a local copy, or changed for another player.
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
  exploitable one on the same Instance.

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
