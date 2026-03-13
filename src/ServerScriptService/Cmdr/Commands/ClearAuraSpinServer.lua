local DataManager = require(game.ServerStorage.Data.DataManager)
local CommandUtil = require(game.ServerScriptService.Cmdr.CommandUtil)

return function(context, player: Player?)
	player = player or context.Executor

	if not player or player.Parent == nil then
		return "Joueur introuvable."
	end

	local profile = DataManager:GetProfile(player)
	local data = profile and profile.Data
	if not (data and data.AuraSpin) then
		return "Data introuvable."
	end

	local name = data.AuraSpin.Name
	local position = data.AuraSpin.Position
	if name == "" or position == "" then
		return `Aucun AuraSpin actif pour {player.Name}.`
	end

	DataManager:ClearAuraSpin(player)
	CommandUtil.ClearAuraSpinUi(player)

	local ok, err = CommandUtil.RebuildPositions(player, { position })
	if not ok then
		return err
	end

	local base = CommandUtil.GetBase(player)
	if base then
		base:RefreshExistingBrainrots()
	end

	return `AuraSpin efface pour {player.Name} ({name}).`
end
