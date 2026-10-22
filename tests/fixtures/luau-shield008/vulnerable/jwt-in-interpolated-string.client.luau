-- Vulnerable: a JSON Web Token inside an interpolated string in a LocalScript.
-- The token is a bearer credential: anyone who reads the script can call the
-- profile API with it until it expires or is revoked.
local userId = game:GetService("Players").LocalPlayer.UserId
local url = `https://api.example.com/v1/profile/{userId}?jwt=eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJmYWtlIn0.FAKEsignatureFAKE123` -- expect: luau-shield008

print(url)
