local MachineModule = require(game.ServerStorage.Module.GameHandler.Machine)

return function(context, seconds: number, player: Player?)
	player = player or context.Executor

	if not player or player.Parent == nil then
		return "Joueur introuvable."
	end

	local machine = MachineModule:Return() or MachineModule:Init(player)
	if not machine then
		return "Fuse Machine introuvable."
	end

	local success, message = machine:SetFuseRemainingTime(player, seconds)
	return message or (success and "Temps de fusion mis a jour." or "Impossible de modifier la fusion.")
end
