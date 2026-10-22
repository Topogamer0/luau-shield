--!strict
-- Vulnerable: arcade cabinet records. The client plays the minigame and sends
-- its result. The server copies the score into a fresh record table: that
-- assignment is not a finding by itself (a table literal created in this
-- function is usually just a reply), but the record is then saved with
-- SetAsync, which is where the client value reaches persistent data.
--
-- Exploit: fire ArcadeFinished with { score = 1e12 } once. The record is shown
-- in the cabinet's Hall of Fame and unlocks the "Arcade Legend" badge.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArcadeFinished = ReplicatedStorage.Remotes.ArcadeFinished :: RemoteEvent
local arcadeStore = DataStoreService:GetDataStore("ArcadeRecords")

local SAVE_COOLDOWN = 15

type ArcadeResult = { score: number }

local lastSave: { [Player]: number } = {}

ArcadeFinished.OnServerEvent:Connect(function(player: Player, result: ArcadeResult)
	local now = os.clock()
	if now - (lastSave[player] or -math.huge) < SAVE_COOLDOWN then
		return
	end
	lastSave[player] = now
	if typeof(result) ~= "table" or typeof(result.score) ~= "number" then
		return
	end

	local record = { Score = 0, Machine = "Classic", SavedAt = os.time() }
	record.Score = result.score
	arcadeStore:SetAsync(`arcade_{player.UserId}`, record) -- expect: luau-shield001
end)
