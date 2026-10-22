-- Vulnerable: someone pasted their .ROBLOSECURITY cookie into a LocalScript to
-- test an API. Anyone who reads it can log in as that account.
local COOKIE = "_|WARNING:-DO-NOT-SHARE-THIS.--Sharing-this-will-allow-someone-to-log-in-as-you-and-to-steal-your-ROBUX-and-items.|_FAKEFAKEFAKE" -- expect: luau-shield008

print(#COOKIE)
