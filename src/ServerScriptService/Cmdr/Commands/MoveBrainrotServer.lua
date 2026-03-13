local DataManager = require(game.ServerStorage.Data.DataManager)
local CommandUtil = require(game.ServerScriptService.Cmdr.CommandUtil)

return function(context, fromPosition: number, toPosition: number, player: Player?)
	player = player or context.Executor

	if not player or player.Parent == nil then
		return "Joueur introuvable."
	end

	local fromPositionString = tostring(fromPosition)
	local toPositionString = tostring(toPosition)
	if fromPositionString == toPositionString then
		return "Les deux slots doivent etre differents."
	end

	local base, err = CommandUtil.GetBase(player)
	if not base then
		return err
	end

	local fromSlot = base.StockBrainrot:FindFirstChild(fromPositionString)
	local toSlot = base.StockBrainrot:FindFirstChild(toPositionString)
	if not fromSlot or not toSlot then
		return "Un des slots est introuvable."
	end

	local sourceBrainrot = DataManager.GetBrainrot(player, fromPositionString)
	if not sourceBrainrot then
		return `Aucun brainrot au slot {fromPositionString}.`
	end

	local targetBrainrot = DataManager.GetBrainrot(player, toPositionString)

	CommandUtil.ClearSlot(fromSlot)
	CommandUtil.ClearSlot(toSlot)

	local info1, info2 = DataManager:ChangePosition(player, fromPositionString, toPositionString)
	if not info1 and not info2 then
		return "Deplacement impossible."
	end

	if info1 then
		base.UpdateBrairot:Fire(info1.Name, info1.Mutation, info1.Position, info1.Slots, info1.HorsLineCash or 0)
	end

	if info2 then
		base.UpdateBrairot:Fire(info2.Name, info2.Mutation, info2.Position, info2.Slots, info2.HorsLineCash or 0)
	end

	base:RefreshExistingBrainrots()
	CommandUtil.RefreshAuraSpinUi(player)
	CommandUtil.RefreshMachineUi(player)

	if targetBrainrot then
		return `Les slots {fromPositionString} et {toPositionString} ont ete echanges.`
	end

	return `{sourceBrainrot.Name} a ete deplace du slot {fromPositionString} vers {toPositionString}.`
end
