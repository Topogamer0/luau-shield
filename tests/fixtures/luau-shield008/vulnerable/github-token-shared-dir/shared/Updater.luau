-- Vulnerable: no Rojo project, but the module lives in a `shared` folder, so
-- it is treated as replicated code. A GitHub token gives write access to the
-- team's repositories.
local Updater = {}

Updater.Repository = "studio/game-assets"
Updater.Token = "ghp_FAKE0000000000000000000000000000000000" -- expect: luau-shield008

return Updater
