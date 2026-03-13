local MessagingService = game:GetService("MessagingService")

local MapMutationManager = require(game.ServerStorage.Module.MapMutationManager)

local GLOBAL_MAP_MUTATION_TOPIC = "GlobalMapMutationEvent"

local function normalizeScope(scope)
	if scope == "Global" or scope == "Globale" then
		return "Global"
	end

	return "Local"
end

return function(context, mutation: string, scope: string?)
	local player = context.Executor
	local selectedScope = normalizeScope(scope)
	local isSupported, normalizedMutation = MapMutationManager:IsSupportedMutation(mutation)
	if not isSupported then
		return `Mutation "{tostring(mutation)}" non supportee pour les maps.`
	end

	local success, message = MapMutationManager:ApplyAdminMutation(normalizedMutation)
	if not success then
		return message
	end

	if selectedScope == "Global" then
		local publishSuccess, publishError = pcall(MessagingService.PublishAsync, MessagingService, GLOBAL_MAP_MUTATION_TOPIC, {
			Mutation = normalizedMutation,
			ExecutorName = player and player.Name or "Console",
			SourceJobId = game.JobId,
		})

		if not publishSuccess then
			warn("[Cmdr.SetMapMutation] PublishAsync failed:", publishError)
			return "Mutation appliquee localement, mais impossible de la propager globalement."
		end

		return `Map mutation {normalizedMutation} appliquee globalement.`
	end

	return message
end
