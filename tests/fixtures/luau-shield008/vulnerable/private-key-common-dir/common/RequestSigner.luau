--!strict
-- Vulnerable: no Rojo project, but the module is in a `common` folder, so it is
-- treated as code shared with clients. It holds the RSA key the game uses to
-- sign requests to the studio's backend: whoever reads it can sign anything
-- (grant purchases, post scores) as the game server.
local RequestSigner = {}

RequestSigner.KeyId = "backend-2025-01"

local SIGNING_PEM = "-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEAFAKEfakeFAKEfake0notArealKEY0123456789abcdef\n-----END RSA PRIVATE KEY-----" -- expect: luau-shield008

function RequestSigner.keyMaterial(): (string, string)
	return RequestSigner.KeyId, SIGNING_PEM
end

return RequestSigner
