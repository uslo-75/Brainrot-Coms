local BrainrotDisplayName = {}

local DISPLAY_NAME_OVERRIDES = {
	["LirilÃ¬ LarilÃ "] = "Lirili Larila",
	["LirilÃƒÂ¬ LarilÃƒÂ "] = "Lirili Larila",
}

function BrainrotDisplayName.Get(name, brainrotData)
	if typeof(brainrotData) == "table" then
		local displayName = brainrotData.DisplayName
		if typeof(displayName) == "string" and displayName ~= "" then
			return DISPLAY_NAME_OVERRIDES[displayName] or displayName
		end
	end

	local rawName = typeof(name) == "string" and name or tostring(name or "")
	return DISPLAY_NAME_OVERRIDES[rawName] or rawName
end

return BrainrotDisplayName
