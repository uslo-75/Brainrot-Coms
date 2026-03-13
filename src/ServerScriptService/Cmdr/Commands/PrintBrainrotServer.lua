local DataManager = require(game.ServerStorage.Data.DataManager)
local CommandUtil = require(game.ServerScriptService.Cmdr.CommandUtil)

local function FormatSlots(slots)
	if typeof(slots) ~= "table" then
		return "-"
	end

	local keys = {}
	for key in pairs(slots) do
		table.insert(keys, key)
	end

	table.sort(keys, function(a, b)
		local aNumber = tonumber(a)
		local bNumber = tonumber(b)
		if aNumber and bNumber then
			return aNumber < bNumber
		end
		return tostring(a) < tostring(b)
	end)

	local parts = {}
	for _, key in ipairs(keys) do
		local value = slots[key]
		table.insert(parts, `{key}={value ~= "" and value or "-"}`)
	end

	return #parts > 0 and table.concat(parts, ", ") or "-"
end

local function IsInFuse(data, position)
	if not (data and data.Fuse and typeof(data.Fuse.Fusing) == "table") then
		return false
	end

	for _, item in ipairs(data.Fuse.Fusing) do
		if item and tostring(item.Position) == tostring(position) then
			return true
		end
	end

	return false
end

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

	local profile = DataManager:GetProfile(player)
	local data = profile and profile.Data
	local name = state.brainrotData and state.brainrotData.Name or (state.model and state.model.Name) or "Unknown"
	local mutation = state.brainrotData and state.brainrotData.Mutation
		or (state.model and state.model:GetAttribute("Mutation"))
		or "Unknown"
	local typeValue, modeValue

	if state.model then
		typeValue = tostring(state.model:GetAttribute("Type") or "nil")
		modeValue = tostring(state.model:GetAttribute("Mode") or "")
	else
		typeValue, modeValue = state.base:GetMode(state.position)
		typeValue = tostring(typeValue or "nil")
		modeValue = tostring(modeValue or "")
	end

	local owner = state.model and tostring(state.model:GetAttribute("Owner") or player.Name) or player.Name
	local enter = tostring(state.slotModel:GetAttribute("Enter"))
	local auraSpin = tostring(data and data.AuraSpin and tostring(data.AuraSpin.Position) == state.position)
	local inFuse = tostring(IsInFuse(data, state.position))
	local slots = FormatSlots(state.brainrotData and state.brainrotData.Slots)

	return `Slot {state.position} | Name={name} | Mutation={mutation} | Type={typeValue} | Mode={modeValue} | Owner={owner} | Enter={enter} | AuraSpin={auraSpin} | Fuse={inFuse} | Slots=[{slots}]`
end
