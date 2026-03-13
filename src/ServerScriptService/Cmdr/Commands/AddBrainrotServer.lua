local DataManager = require(game.ServerStorage.Data.DataManager)
local BaseModule = require(game.ServerStorage.Module.GameHandler.Base)
local BrainrotSelect = require(game.ServerStorage.Module.BrainrotSelect)
local BrainrotList = require(game.ServerStorage.List.BrainrotList)
local MutationModule = require(game.ServerStorage.Module.RollModule.Mutation)
local BrainrotDisplayName = require(game.ReplicatedStorage.Module.BrainrotDisplayName)

local function NormalizeLookup(value)
	return string.lower((tostring(value or "")):gsub("[%s%p_]+", ""))
end

local function ResolveBrainrotName(brainrotName)
	if BrainrotList[brainrotName] then
		return brainrotName
	end

	local lookup = NormalizeLookup(brainrotName)
	for name, data in pairs(BrainrotList) do
		if NormalizeLookup(name) == lookup or NormalizeLookup(data.DisplayName) == lookup then
			return name
		end
	end

	return nil
end

local function ResolveMutationName(mutation)
	local normalized = MutationModule:NormalizeName(mutation or "Normal")
	return MutationModule.Mutation[normalized] and normalized or nil
end

return function(context, brainrotName: string, mutation: string, slotcount: number, player: Player?)
	player = player or context.Executor

	if not player or player.Parent == nil then
		return "Joueur introuvable."
	end

	local newBase = BaseModule.GetBase(player)
	if not newBase then
		return "Base introuvable."
	end

	local resolvedName = ResolveBrainrotName(brainrotName)
	if not resolvedName then
		return "Brainrot invalide."
	end

	local resolvedMutation = ResolveMutationName(mutation)
	if not resolvedMutation then
		return "Mutation invalide."
	end

	local slotsCount = math.max(1, math.floor(tonumber(slotcount) or 1))
	local positionSelect = newBase:GetSlotRequire()
	if positionSelect == nil then
		return "Aucun slot disponible."
	end

	local slots = BrainrotSelect:GetSlotsTable(slotsCount)
	local brainrotData = DataManager.AddBrainrot(
		player,
		resolvedName,
		resolvedMutation,
		slots,
		positionSelect.Name
	)

	if not brainrotData then
		return "Une erreur est survenue."
	end

	newBase.UpdateBrairot:Fire(
		brainrotData.Name,
		brainrotData.Mutation,
		brainrotData.Position,
		brainrotData.Slots,
		0
	)

	return `{player.Name} a recu {BrainrotDisplayName.Get(brainrotData.Name, BrainrotList[brainrotData.Name])} ({brainrotData.Mutation}) au slot {positionSelect.Name} avec {slotsCount} slot(s).`
end
