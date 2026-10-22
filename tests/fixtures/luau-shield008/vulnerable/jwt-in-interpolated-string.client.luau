-- Vulnerable: a JSON Web Token inside an interpolated string in a LocalScript.
local userId = game:GetService("Players").LocalPlayer.UserId
local url = `https://api.example.com/v1/profile/{userId}?jwt=eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJmYWtlIn0.FAKEsignatureFAKE123` -- expect: luau-shield008

print(url)
