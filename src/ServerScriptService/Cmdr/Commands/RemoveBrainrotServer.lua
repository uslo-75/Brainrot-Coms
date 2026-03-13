local DataManager = require(game.ServerStorage.Data.DataManager)
local CommandUtil = require(game.ServerScriptService.Cmdr.CommandUtil)

return function(context, position: number, player: Player?)
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

	if not state.brainrotData and not state.model then
		return `Aucun brainrot au slot {position}.`
	end

	local name = state.brainrotData and state.brainrotData.Name or (state.model and state.model.Name) or "Brainrot"
	CommandUtil.ClearMachineStateForPosition(player, state.position)

	local removedData = false
	if state.brainrotData then
		removedData = DataManager.RemoveBrainrot(player, state.position)
	end

	CommandUtil.ClearSlot(state.slotModel)
	state.base:RefreshExistingBrainrots()

	if removedData then
		return `{name} a ete supprime du slot {state.position}.`
	end

	return `Le modele orphelin du slot {state.position} a ete nettoye.`
end
