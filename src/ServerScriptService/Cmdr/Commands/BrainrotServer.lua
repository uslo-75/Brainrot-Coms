local DataManager = require(game.ServerStorage.Data.DataManager)
local BaseModule = require(game.ServerStorage.Module.GameHandler.Base)
local BrainrotSelect = require(game.ServerStorage.Module.BrainrotSelect)
local AuraList = require(game.ServerStorage.List.AuraList)

local ACTION_TYPES = {
	[""] = "Default",
	default = "Default",
	set = "Default",
	delete = "Delete",
	clear = "Delete",
	all = "All",
	fill = "All",
	alldelete = "AllDelete",
	clearall = "AllDelete",
	reset = "AllDelete",
}

local function NormalizeLookup(value)
	return string.lower((tostring(value or "")):gsub("[%s%p_]+", ""))
end

local function ResolveActionType(actionType)
	if not actionType then
		return "Default"
	end

	return ACTION_TYPES[NormalizeLookup(actionType)]
end

local function ResolveAuraName(auraName)
	if auraName == nil then
		return nil
	end

	local trimmed = tostring(auraName):match("^%s*(.-)%s*$") or ""
	if trimmed == "" then
		return ""
	end

	local lookup = NormalizeLookup(trimmed)
	if lookup == "none" or lookup == "clear" or lookup == "empty" then
		return ""
	end

	if AuraList[trimmed] then
		return trimmed
	end

	for name, data in pairs(AuraList) do
		if NormalizeLookup(name) == lookup or NormalizeLookup(data.DisplayName) == lookup then
			return name
		end
	end

	return nil
end

local function ParseAuraAssignments(text)
	local result = {}

	if typeof(text) ~= "string" then
		return result
	end

	for index, name in string.gmatch(text, "%((%d+)%s*[/=:%-]%s*([^%)]+)%)") do
		result[tonumber(index)] = name
	end

	if next(result) ~= nil then
		return result
	end

	for chunk in string.gmatch(text, "[^,;]+") do
		local index, name = chunk:match("^%s*(%d+)%s*[/=:%-]%s*(.-)%s*$")
		if index and name then
			result[tonumber(index)] = name
		end
	end

	return result
end

local function ExtractSlotNumbers(text)
	local result = {}
	local seen = {}

	text = tostring(text or ""):gsub("[%(%)]", "")
	for item in string.gmatch(text, "[^,;/%s]+") do
		local slotNumber = tonumber(item)
		if slotNumber and not seen[slotNumber] then
			seen[slotNumber] = true
			table.insert(result, slotNumber)
		end
	end

	return result
end

local function RefreshBrainrotModel(model, mutation, slots)
	if model then
		BrainrotSelect:SetInfoByBrairot(model, mutation, slots)
	end
end

local function BuildIgnoredMessage(invalidSlots, invalidAuras)
	local parts = {}

	if #invalidSlots > 0 then
		table.insert(parts, `slots ignores: {table.concat(invalidSlots, ", ")}`)
	end

	if #invalidAuras > 0 then
		table.insert(parts, `auras invalides: {table.concat(invalidAuras, ", ")}`)
	end

	if #parts == 0 then
		return ""
	end

	return ` ({table.concat(parts, " | ")})`
end

return function(context, Position: number, AurasName: string, Types: string, player: Player?)
	player = player or context.Executor

	if not player or player.Parent == nil then
		return "Joueur introuvable."
	end

	local newBase = BaseModule.GetBase(player)
	local brairotData = DataManager.GetBrainrot(player, Position)
	local model = newBase and newBase:GetModelBySlots(Position)
	local actionType = ResolveActionType(Types)

	if not brairotData or not newBase then
		return `Aucun brainrot trouve a la position {Position}.`
	end

	if typeof(brairotData.Slots) ~= "table" then
		brairotData.Slots = {}
	end

	if not actionType then
		return `Type {Types} introuvable. (Default, Delete, All, AllDelete)`
	end

	if actionType == "Default" then
		local assignments = ParseAuraAssignments(AurasName)
		if next(assignments) == nil then
			return "Format invalide. Utilise (1/Wind),(2/Bubble) ou 1:Wind,2:Bubble."
		end

		local changedCount = 0
		local invalidSlots = {}
		local invalidAuras = {}

		for index, value in pairs(assignments) do
			local slotKey = tostring(index)
			if brairotData.Slots[slotKey] ~= nil then
				local auraName = ResolveAuraName(value)
				if auraName ~= nil then
					if brairotData.Slots[slotKey] ~= auraName then
						brairotData.Slots[slotKey] = auraName
						changedCount += 1
					end
				else
					table.insert(invalidAuras, tostring(value))
				end
			else
				table.insert(invalidSlots, tostring(index))
			end
		end

		if changedCount == 0 then
			return `Aucun slot mis a jour{BuildIgnoredMessage(invalidSlots, invalidAuras)}.`
		end

		RefreshBrainrotModel(model, brairotData.Mutation, brairotData.Slots)
		return `{changedCount} slot(s) mis a jour{BuildIgnoredMessage(invalidSlots, invalidAuras)}.`
	end

	if actionType == "Delete" then
		local slots = ExtractSlotNumbers(AurasName)
		if #slots == 0 then
			return "Aucun slot valide a vider."
		end

		local changedCount = 0
		local invalidSlots = {}

		for _, slotNumber in ipairs(slots) do
			local slotKey = tostring(slotNumber)
			if brairotData.Slots[slotKey] ~= nil then
				if brairotData.Slots[slotKey] ~= "" then
					brairotData.Slots[slotKey] = ""
					changedCount += 1
				end
			else
				table.insert(invalidSlots, tostring(slotNumber))
			end
		end

		if changedCount == 0 then
			return `Aucun slot vide modifie{BuildIgnoredMessage(invalidSlots, {})}.`
		end

		RefreshBrainrotModel(model, brairotData.Mutation, brairotData.Slots)
		return `{changedCount} slot(s) vide(s){BuildIgnoredMessage(invalidSlots, {})}.`
	end

	if actionType == "All" then
		local auraName = ResolveAuraName(AurasName)
		if auraName == nil or auraName == "" then
			return "Aura invalide."
		end

		local changedCount = 0
		for index in pairs(brairotData.Slots) do
			if brairotData.Slots[index] ~= auraName then
				brairotData.Slots[index] = auraName
				changedCount += 1
			end
		end

		RefreshBrainrotModel(model, brairotData.Mutation, brairotData.Slots)
		return `{auraName} appliquee sur {changedCount} slot(s).`
	end

	local changedCount = 0
	for index in pairs(brairotData.Slots) do
		if brairotData.Slots[index] ~= "" then
			brairotData.Slots[index] = ""
			changedCount += 1
		end
	end

	RefreshBrainrotModel(model, brairotData.Mutation, brairotData.Slots)
	return `Toutes les auras ont ete retirees sur {changedCount} slot(s).`
end
