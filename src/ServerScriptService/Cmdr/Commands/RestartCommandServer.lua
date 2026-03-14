local MessagingService = game:GetService("MessagingService")
local ServerStorage = game:GetService("ServerStorage")

local ServerRestartManager = require(ServerStorage.Module.ServerRestartManager)

local function normalizeScope(value)
	if value == "Global" or value == "Globale" then
		return "Global"
	end

	return "Local"
end

return function(context, scope: string?)
	local player = context.Executor
	local executorName = player and player.Name or "Console"
	local selectedScope = normalizeScope(scope)

	if selectedScope == "Global" then
		local publishSuccess, publishError = pcall(MessagingService.PublishAsync, MessagingService, ServerRestartManager.GLOBAL_TOPIC, {
			ExecutorName = executorName,
			SourceJobId = game.JobId,
		})

		if not publishSuccess then
			warn("[Cmdr.RestartServer] PublishAsync failed:", publishError)
			local localSuccess, localMessage = ServerRestartManager:RestartLocal(executorName, "Local")
			if not localSuccess then
				return localMessage
			end

			return "Global restart failed to publish; local restart started instead."
		end

		local localSuccess, localMessage = ServerRestartManager:RestartLocal(executorName, "Global")
		if not localSuccess then
			return localMessage
		end

		return "Global server restart started."
	end

	local success, message = ServerRestartManager:RestartLocal(executorName, "Local")
	if not success then
		return message
	end

	return message
end
