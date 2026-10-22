--!strict
-- Vulnerable: a client-side admin panel "protected" by passwords stored in the
-- LocalScript. An exploiter decompiles the script and reads both passwords
-- (which often also guard the studio's other tools). A password without digits
-- or with spaces is still a secret.
local Players = game:GetService("Players")

local OWNER_PASSWORD = "PurpleMonkeyDishwasherLadder" -- expect: luau-shield008
local moderatorPassphrase = "tangerine lantern over the harbor" -- expect: luau-shield008

local panel = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("AdminPanel") :: ScreenGui
local input = panel:WaitForChild("PasswordBox") :: TextBox

input.FocusLost:Connect(function(enterPressed: boolean)
	if not enterPressed then
		return
	end
	local level = if input.Text == OWNER_PASSWORD
		then "Owner"
		elseif input.Text == moderatorPassphrase then "Moderator"
		else nil
	if level then
		panel:SetAttribute("Unlocked", level)
	end
end)
