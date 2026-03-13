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

	local cleared, auraCleared, fuseCleared = CommandUtil.ClearMachineStateForPosition(player, state.position)
	if not cleared then
		return `Aucun brainrot en machine au slot {state.position}.`
	end

	local ok, err = CommandUtil.RebuildPositions(player, { state.position })
	if not ok then
		return err
	end

	state.base:RefreshExistingBrainrots()

	local name = state.brainrotData and state.brainrotData.Name or (state.model and state.model.Name) or "Brainrot"
	if auraCleared and fuseCleared then
		return `{name} a ete retire de toutes les machines et restaure sur son slot.`
	end

	if auraCleared then
		return `{name} a ete retire de l'AuraSpin et restaure sur son slot.`
	end

	return `{name} a ete retire de la Fuse Machine et restaure sur son slot.`
end
