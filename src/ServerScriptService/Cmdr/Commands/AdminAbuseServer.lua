local MessagingService = game:GetService("MessagingService")

local MapMutationManager = require(game.ServerStorage.Module.MapMutationManager)

local GLOBAL_ADMIN_ABUSE_TOPIC = "GlobalAdminAbuseEvent"

local function normalizeScope(scope)
	if scope == "Global" or scope == "Globale" then
		return "Global"
	end

	return "Local"
end

return function(context, abuseName: string, scope: string?)
	local player = context.Executor
	local selectedScope = normalizeScope(scope)
	local isSupported, normalizedAbuse = MapMutationManager:IsSupportedAdminAbuse(abuseName)
	if not isSupported then
		return `Admin abuse "{tostring(abuseName)}" non supporte.`
	end

	local success, message = MapMutationManager:ApplyAdminAbuse(normalizedAbuse)
	if not success then
		return message
	end

	if selectedScope == "Global" then
		local publishSuccess, publishError = pcall(MessagingService.PublishAsync, MessagingService, GLOBAL_ADMIN_ABUSE_TOPIC, {
			Abuse = normalizedAbuse,
			ExecutorName = player and player.Name or "Console",
			SourceJobId = game.JobId,
		})

		if not publishSuccess then
			warn("[Cmdr.AdminAbuse] PublishAsync failed:", publishError)
			return "Mode applique localement, mais impossible de le propager globalement."
		end

		return `Admin abuse {normalizedAbuse} applique globalement.`
	end

	return message
end
