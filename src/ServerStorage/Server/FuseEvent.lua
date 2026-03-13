local FuseEvent = {}

local DataManager = require(game.ServerStorage.Data.DataManager)
local MachineModule = require(game.ServerStorage.Module.GameHandler.Machine)
local DB = {}

function FuseEvent:Init(player, ...)
	local Halls = {...}
	local EventType = Halls[1]
	local newMachine = MachineModule:Return() or MachineModule:Init(player)
	
	if EventType == "Fuse" then
		if not DB[player] then
			DB[player] = true
			task.delay(.15, function() DB[player] = nil end)

			local profile = DataManager:GetProfile(player)
			local data = profile and profile.Data
			local fuseData = data and data.Fuse

			if fuseData and fuseData.FuseMode ~= "None" and (fuseData.FuseEndTime or 0) <= os.time() then
				return newMachine:ClaimRewardToHands(player)
			end

			local succes, mess = newMachine:StartFuse(player)
			return succes, mess
		end
	elseif EventType == "Cancel" then
		if not DB[player] then
			DB[player] = true
			task.delay(.15, function() DB[player] = nil end)

			return newMachine:CancelFuse(player)
		end
	elseif EventType == "ReturnSlot" then
		local slotIndex = Halls[2]
		return newMachine:ReturnSlot(player, slotIndex)
	elseif EventType == "ReturnAllBeforeReset" then
		local success = newMachine:ReturnAll(player)
		return success
	end
end

return FuseEvent
