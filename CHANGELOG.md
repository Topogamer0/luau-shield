# Changelog

All notable changes to luau-shield are documented in this file. The format is
based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the
project follows [Semantic Versioning](https://semver.org/).

## [0.2.0] - 2026-10-22

This release fixes the false positives reported after running v0.1.0 on a
real 144-file game (5 warnings, all false positives), without losing any
vulnerable case of the test corpus.

### Added

- **`info` severity**, below `low`. It is used for findings that are only
  reachable by admins (see below) and is hidden at the default
  `min-severity = "low"`; use `--min-severity info` to see them. `info` is
  accepted by `--min-severity`, `--fail-on`, `min-severity`, `fail-on` and
  `[rules]` severities, is counted in the summary, and is written as SARIF
  level `note`.
- **Permission guards** (`[guards]` in `luau-shield.toml`). Code that only runs
  after a permission check on the player who sent the request
  (`if not Admins.isAdmin(sender) then return end`,
  `Permissions:hasPermission(player, "Ban")`) is reported as `info` with
  "(admin only: ...)" in the message. Built-in names: `isAdmin`, `isOwner`,
  `isCreator`, `isModerator`, `isStaff`, `isDeveloper`, `hasPermission` and
  similar; add your own with `[guards] functions`, or turn the built-in names
  off with `[guards] defaults = false`. Checks on a player chosen by the
  client, or on another object (`isOwner(player, plot)`), are not guards.
  luau-shield004 (code execution) is never downgraded.
- **Sanitizer hints.** When the value of a finding comes out of a function
  named like a sanitizer (`Look.sanitize`, `validateLook`, `clampIndex`...)
  that luau-shield could not follow, or that does not make the required checks
  on every path, the fix suggests declaring it in `[[sanitizers]]`.
- `CHANGELOG.md`.

### Changed

- **Loops over tables with known keys run once per field** (luau-shield001).
  `for key, value in patch do changed[key] = value end`, where `patch` is a
  table built by the server such as `{ coins = amount }`, no longer makes
  every field of `changed` (`changed.level`, `changed.xp`) carry `amount`.
  Tables sent by the client still taint every field.
- **Digits-only patterns reject NaN** (luau-shield001).
  `tonumber(string.match(text, "(%-?%d+)"))` can never be NaN, so with bounds
  (`math.clamp`) the number is fully checked.
- **Calls too deep to follow use a return summary** (luau-shield001 and the
  other value rules). When a call is beyond `max-call-depth` or the analysis
  budget, luau-shield analyses the function once with placeholder arguments
  and reuses what it returns, including its checks. A sanitizer that builds a
  new table field by field (`Look.sanitize(raw)` returning
  `{ hair = clampIndex(raw.hair, 10, 1), ... }`) now protects its result even
  at the end of a long call chain.
- **State machines limit a remote** (luau-shield007). A handler that tests a
  state and changes it before the expensive work, so that the same test fails
  on the next request, is not reported: `if state[player] ~= "Playing" then
  return end; state[player] = "Menu"; store:UpdateAsync(...)`, or
  `if data[p].Slots[s] then data[p].Slots[s] = nil; store:UpdateAsync(...) end`
  in a helper. Writing back the value that passes the test does not count.
- **Conditional work is described as such** (luau-shield007). When all the
  expensive calls of a handler run inside an `if`, the message says the
  handler calls them "when a condition [in `function`] holds" and asks to
  check that a client cannot make it hold on every request, instead of "on
  every request". The severity is unchanged.

### Fixed

- The four false-positive patterns above, each covered by a safe fixture
  (no warning) and by vulnerable variants that are still reported, in
  `tests/fixtures/luau-shield001` and `tests/fixtures/luau-shield007`.

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
