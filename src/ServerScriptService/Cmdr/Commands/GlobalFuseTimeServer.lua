local Players = game:GetService("Players")
local MessagingService = game:GetService("MessagingService")
local ServerStorage = game:GetService("ServerStorage")

local MachineModule = require(ServerStorage.Module.GameHandler.Machine)

local GLOBAL_FUSE_TIME_TOPIC = "GlobalFuseTimeEvent"

local function applyFuseTimeToServer(remainingSeconds)
	local updatedCount = 0

	for _, player in ipairs(Players:GetPlayers()) do
		local machine = MachineModule:Return() or MachineModule:Init(player)
		if machine then
			local success = machine:SetFuseRemainingTime(player, remainingSeconds)
			if success then
				updatedCount += 1
			end
		end
	end

	return updatedCount
end

return function(context, seconds: number)
	local executor = context.Executor
	local updatedCount = applyFuseTimeToServer(seconds)

	local publishSuccess, publishError = pcall(MessagingService.PublishAsync, MessagingService, GLOBAL_FUSE_TIME_TOPIC, {
		Seconds = seconds,
		ExecutorName = executor and executor.Name or "Console",
		SourceJobId = game.JobId,
	})

	if not publishSuccess then
		warn("[Cmdr.SetFuseTimeGlobal] PublishAsync failed:", publishError)
		return `Temps de fusion applique localement sur {updatedCount} fusion(s), mais impossible de le propager globalement.`
	end

	return `Temps de fusion global applique. {updatedCount} fusion(s) mises a jour sur ce serveur.`
end
