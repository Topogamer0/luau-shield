# luau-shield008: client-exposed-secret

A webhook URL, API key, token, password or private key is hard-coded in a
string literal of code whose source is sent to every client.

| Severity | Default | Applies to |
| --- | --- | --- |
| critical | enabled | replicated code: `*.client.luau` LocalScripts and ModuleScripts that replicate to clients; never `*.server.luau` Scripts, server modules or files of unknown context |

## What it detects

Unlike the other rules, luau-shield008 does not follow data. It looks at every
string literal of the files whose code reaches clients and reports the ones
that hold a credential.

**Which files.** The rule runs on the files that every player receives (see
[Where code runs](../analysis.md#1-where-code-runs)):

| File | Checked |
| --- | --- |
| `*.client.luau` / `*.client.lua` (LocalScript), wherever it is | yes |
| ModuleScript under `ReplicatedStorage`, `ReplicatedFirst`, `StarterPlayer`, `StarterGui`, `StarterPack` or `Workspace` | yes |
| `*.server.luau` / `*.server.lua` (Script) | no |
| ModuleScript under `ServerScriptService` or `ServerStorage` | no |
| anything else (unknown context) | no |

The location of a module comes from the Rojo project (`default.project.json`,
or the file passed with `--project`), and the service at the top of that
location decides. A folder named `Server` inside `ReplicatedStorage` is still
replicated, and a folder named `Shared` inside `ServerScriptService` is still
server-only. Without a project file, directory names are used as hints:
`client`, `StarterPlayer`, `StarterPlayerScripts`, `StarterCharacterScripts`,
`StarterGui`, `StarterPack` and `ReplicatedFirst` mean client code, `shared`,
`common` and `ReplicatedStorage` mean a replicated module, and `server`,
`ServerScriptService` and `ServerStorage` mean server code.

**Which strings.** Every string literal is checked: quoted strings, long
strings (`[[...]]`) and the text parts of interpolated strings
(`` `...{x}...` ``). A literal is a secret when it matches one of these
formats, whatever variable it is stored in or function it is passed to:

| Secret | Recognised by |
| --- | --- |
| Discord webhook | `https://discord.com/api/webhooks/<id>/<token>`, also `discordapp.com`, the `ptb.` and `canary.` subdomains and versioned paths (`/api/v10/webhooks/...`) |
| Guilded and Slack webhooks | `https://media.guilded.gg/webhooks/...`, `https://hooks.slack.com/services/...` |
| OpenAI API key | `sk-...`, `sk-proj-...` |
| Anthropic API key | `sk-ant-...` |
| GitHub token | `ghp_`, `gho_`, `ghu_`, `ghs_`, `ghr_`, `github_pat_` |
| AWS access key | `AKIA` followed by 16 characters |
| Google API key | `AIza` followed by 35 characters |
| Stripe live key | `sk_live_...`, `rk_live_...` |
| Telegram bot token | `<bot id>:<35 characters>` |
| `.ROBLOSECURITY` cookie | `_|WARNING:-DO-NOT-SHARE-THIS.` |
| Private key | `-----BEGIN ... PRIVATE KEY-----` (PEM) |
| JSON Web Token | `eyJ...` `.` `eyJ...` `.` signature |

A literal in an unknown format is also a secret when it is at least 16
characters long, does not look like a placeholder, and is stored under a name
that contains `apikey`, `api_key`, `secret`, `token`, `password`, `passwd`,
`webhook`, `auth`, `bearer`, `private_key`, `access_key` or `client_secret`
(case is ignored). The name can be a variable, a field or a table key:

```lua
local apiKey = "lb_9f3K2m8Q1x7Z4v6N0p5R2t8W"
LicenseServer.Token = "a8f3k29dk3l2m9x0q7w6e5r4"
headers["x-auth-token"] = "9f8e7d6c5b4a39281706f5e4d3c2b1a0"
local Settings = {
	FeedbackWebhook = "https://webhook.lewisakura.moe/api/webhooks/1188990011223344556/FAKEproxyTOKEN0123456789abcdef",
	["X-Api-Key"] = "tlm_live_4Qx9Zr2Lk7Vb1Nw8Tp3Hs6Jd",
}
```

This is how webhook proxies, passwords and the keys of smaller services are
found. `Authorization` header values such as `"Bearer 7c1f0e9d..."` are
covered the same way (the `Bearer ` prefix does not count towards the
length).

Placeholders are not secrets: `"YOUR_API_KEY_HERE"`, `"xxxxxxxx"`,
`"<token>"`, `""`, and values made of one repeated character. Short values
(`tokenLabel = "Tokens: 0"`) are not secrets either.

The finding is reported on the line of the string literal (for a long string
that spans several lines, the line where it starts). Comments are not
checked: they are not part of the compiled bytecode that clients receive.

## Why it is dangerous

Roblox sends every LocalScript and every replicated ModuleScript to each
player's device, and the code is only compiled, not hidden. An exploiter
does not even need a decompiler for a module: their executor can `require` it
and print the table.

```lua
-- Run by the exploiter in their executor, not by your game.
local Settings = require(game:GetService("ReplicatedStorage").Shared.Settings)
print(Settings.FeedbackWebhook) -- the full URL: webhook id and token
```

What happens next depends on the secret, and none of it can be undone by
updating the game:

- **Webhook:** anyone can post to your Discord channel (scam links,
  `@everyone` spam, fake "staff" announcements) or delete the webhook with a
  single `DELETE` request.
- **AI and other paid APIs** (OpenAI, Anthropic, Google): the key is used for
  someone else's projects and billed to you until it is revoked.
- **Trello, GitHub, backend tokens:** the board or repository behind it can
  be edited. A Trello-based ban list lets the exploiter unban themselves and
  ban everyone else; a GitHub token can push code to your repositories.
- **`.ROBLOSECURITY` cookie, passwords:** the account or the admin panel they
  protect is taken over.

Every published version of the place keeps the secret, so a leaked credential
must be revoked, not just deleted from the code. There is also never a reason
to put a credential in client code: `HttpService` requests can only be made
by the server.

## Vulnerable example

```lua
-- ReplicatedStorage/Shared/Settings.luau
-- Read by the feedback UI (client) and by the feedback script (server).
local Settings = {
	MaxFeedbackLength = 300,
	FeedbackCooldown = 60,
	FeedbackWebhook = "https://discord.com/api/webhooks/1188990011223344556/FAKEtokenFAKEtoken0123456789abcdefghijklmnopqrstuvwxyzFAKE", -- luau-shield008
}

return Settings
```

The server script that posts the feedback can be perfectly written: the
problem is that the URL lives in a module every client receives.

## Fixed example

Keep only public values in the replicated module, and let the server read
the webhook from [Roblox secrets](https://create.roblox.com/docs/reference/engine/classes/HttpService#GetSecret)
(configured in Creator Hub, so it is not even in the place file or the
repository):

```lua
-- ReplicatedStorage/Shared/Settings.luau
-- Only values every player may see.
local Settings = {
	MaxFeedbackLength = 300,
	FeedbackCooldown = 60,
}

return Settings
```

```lua
-- ServerScriptService/Feedback.server.luau
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Settings)

-- Stored in Creator Hub (Secrets), never in the place or the repository.
local feedbackWebhook = HttpService:GetSecret("feedback_webhook")

local SendFeedback = ReplicatedStorage.Remotes.SendFeedback :: RemoteEvent
local lastSent: { [Player]: number } = {}

SendFeedback.OnServerEvent:Connect(function(player: Player, text: unknown)
	local now = os.clock()
	if now - (lastSent[player] or -math.huge) < Settings.FeedbackCooldown then
		return
	end
	if typeof(text) ~= "string" or #text > Settings.MaxFeedbackLength then
		return
	end
	lastSent[player] = now
	local body = HttpService:JSONEncode({ content = `{player.Name}: {text}` })
	HttpService:PostAsync(feedbackWebhook, body)
end)
```

The handler is clean for the other rules too: the text has a type check and a
length limit ([luau-shield005](luau-shield005.md)) and `os.clock()` is
rate-limit evidence ([luau-shield007](luau-shield007.md)). Then revoke the old
webhook and create a new one: the old URL is in every version of the place
that was published with it.

## What counts as a check

luau-shield008 has no value checks: none of the facts of
[Checks](../analysis.md#4-checks-sanitizers) (type, bounds, NaN rejected,
allow-lists, ...) apply, and type annotations change nothing. What satisfies
the rule is **where the secret is**:

```lua
-- Best: a Roblox secret, read on the server
local apiKey = HttpService:GetSecret("openai_key")

-- Acceptable: a literal in server-only code
-- ServerStorage/Secrets.luau, ServerScriptService/Webhooks.luau, *.server.luau

-- Fine in client code: placeholders in a template
local Config = {
	WebhookUrl = "YOUR_WEBHOOK_URL_HERE",
	ApiKey = "",
}
```

When the client needs something done with a credential, let it ask the server
through a remote and do the request there (with the checks the other rules
ask for).

What is **not** enough:

- **A folder named `Server`, `Private` or `Secrets` inside `ReplicatedStorage`
  or `Workspace`.** Everything in those services replicates, whatever the
  folder is called.
- **`if RunService:IsServer() then ... end` around the secret** in a shared
  module. The check runs on the client too, but the literal is in the
  bytecode the client received.
- **Obfuscation.** Splitting the value (`"sk-proj-" .. rest`), reversing it,
  encoding it in base64 or building it with `string.char` hides it from
  luau-shield, not from an exploiter: the module computes the real value
  whenever it runs.
- **Deleting the line.** Published versions and the repository history keep
  the old value: revoke it.

## Limitations

- **Names and formats only.** A credential in an unknown format is only found
  through the name it is stored under. `local url = "https://..."` with a
  neutral name, or a key passed straight to a function
  (`Trello.new("3f9a1c7e...")`), is not reported.
- **Built values are not followed.** Concatenation, `string.format`,
  `string.char`, `string.reverse` and decoding at runtime are not evaluated,
  so obfuscated secrets are missed (see above).
- **Only Luau source is scanned.** Values stored in instances
  (`StringValue`s, attributes, `Configuration` objects in `.rbxm`,
  `.model.json` or `.meta.json` files) are not checked, even when they
  replicate.
- **Unknown context is skipped.** A module outside the Rojo project and
  without a directory hint is not checked. Run luau-shield with your
  `default.project.json` (or `--project`) so every module has a location.
- **Run context comes from the file name.** A `*.server.luau` Script whose
  `RunContext` is set to `Client` (for example in a `.meta.json` file) runs
  on, and is sent to, clients, but is treated as a server Script.
- **Credential-like names catch other values.** A long, non-secret value
  under such a name is reported, for example
  `local TOKEN_ICON = "rbxassetid://1234567890123"`. Rename the variable to
  a name without those words (`COIN_ICON`) or suppress the finding.
- **Placeholders are guessed.** A value containing `your`, `here`,
  `example`, `xxxx`, `todo`, `changeme`, `<` or `{` is taken for a
  placeholder, so a real password that happens to contain one of them
  (`"WhereIsMyPassword42"`) is missed.
- **Public keys are reported like private ones.** Some services hand out
  keys that are meant to be public (publishable keys, client ids). If the
  value is stored under a credential-like name, or uses a format above,
  suppress the finding with a reason.

## Suppressing

Suppress a single finding with a comment and a reason, at the end of the
reported line or on the line directly above it (see
[Suppressing findings](../configuration.md#suppressing-findings)). Only do
it for values that are really public: a suppression does not make a leaked
credential safe.

```lua
local TOKEN_ICON = "rbxassetid://1234567890123" -- luau-shield-ignore: luau-shield008 a public image id, not a credential

-- luau-shield-ignore: luau-shield008 public key of the sandbox environment, no access to production
local SANDBOX_API_KEY = "sbx_7c1f0e9d8b6a5c4e3f2a1b0c"
```

For a long string that spans several lines, put the comment on the line
above the one where the string starts.

Suppress the rule for a whole file with a comment at the top of the file:

```lua
-- luau-shield-ignore-file: luau-shield008 test fixtures with revoked credentials
```

Turn the rule off in `luau-shield.toml` (or for one run with
`luau-shield check src --disable luau-shield008`):

```toml
[rules]
luau-shield008 = "off"
```

To skip only some files (for example a folder of revoked test credentials),
prefer `ignore = ["tests/secrets/**"]` in the configuration over turning the
rule off for the whole project.
