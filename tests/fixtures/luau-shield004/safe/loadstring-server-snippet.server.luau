-- Safe (scary but fine): the client only picks the NAME of a built-in snippet;
-- the chunk compiled by loadstring is a constant, developer-written string read
-- from a server table. Client input never reaches the compiler.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SNIPPETS = {
	hello = "return 'hello from the server'",
	version = "return 42",
}

ReplicatedStorage.Remotes.RunSnippet.OnServerInvoke = function(player: Player, name: string)
	local source = SNIPPETS[name]
	if not source then
		return nil
	end
	local chunk = loadstring(source)
	return chunk and chunk()
end
