local DataManager = require(game.ServerStorage.Data.DataManager)
local MutationModule = require(game.ServerStorage.Module.RollModule.Mutation)
local CommandUtil = require(game.ServerScriptService.Cmdr.CommandUtil)

local function SyncFuseMutation(player, position, mutation)
	local profile = DataManager:GetProfile(player)
	local data = profile and profile.Data

	if data and data.Fuse and typeof(data.Fuse.Fusing) == "table" then
		for _, item in ipairs(data.Fuse.Fusing) do
			if item and tostring(item.Position) == tostring(position) then
				item.Mutation = mutation
			end
		end
	end
end

return function(context, position: number, mutation: string, player: Player?)
	player = player or context.Executor

	if not player or player.Parent == nil then
		return "Joueur introuvable."
	end

	local state = CommandUtil.GetState(player, position)
	if not (state.base and state.base.StockBrainrot) then
		return "Base introuvable."
	end

	if not state.slotModel then
		return `Slot {position} introuvable.`
	end

	if not state.brainrotData then
		return `Aucun brainrot au slot {position}.`
	end

	local resolvedMutation = MutationModule:NormalizeName(mutation or "Normal")
	if not MutationModule.Mutation[resolvedMutation] then
		return "Mutation invalide."
	end

	if state.brainrotData.Mutation == resolvedMutation then
		return `{state.brainrotData.Name} est deja en {resolvedMutation}.`
	end

	state.brainrotData.Mutation = resolvedMutation
	SyncFuseMutation(player, state.position, resolvedMutation)
	DataManager.AddIndex(player, state.brainrotData.Name, resolvedMutation)

	local ok, err = CommandUtil.RebuildPositions(player, { state.position })
	if not ok then
		return err
	end

	state.base:RefreshExistingBrainrots()
	CommandUtil.RefreshAuraSpinUi(player)
	CommandUtil.RefreshMachineUi(player)

	return `{state.brainrotData.Name} au slot {state.position} est maintenant {resolvedMutation}.`
end
