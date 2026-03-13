local PlayerSettingsConfig = {}

PlayerSettingsConfig.LoadedAttribute = "ClientSettingsLoaded"

PlayerSettingsConfig.ToggleOrder = {
	"MusicEnabled",
	"BrainrotSoundsEnabled",
	"CameraEffectsEnabled",
	"ModelVFXEnabled",
}

PlayerSettingsConfig.ToggleDefinitions = {
	MusicEnabled = {
		Attribute = "SettingMusicEnabled",
		Default = true,
		Label = "Music",
		Description = "Enable or disable the lobby music.",
	},
	BrainrotSoundsEnabled = {
		Attribute = "SettingBrainrotSoundsEnabled",
		Default = true,
		Label = "Brainrot Sounds",
		Description = "Enable or disable the brainrot spin sounds.",
	},
	CameraEffectsEnabled = {
		Attribute = "SettingCameraEffectsEnabled",
		Default = true,
		Label = "Camera Sway",
		Description = "Enable or disable the client camera sway.",
	},
	ModelVFXEnabled = {
		Attribute = "SettingModelVFXEnabled",
		Default = true,
		Label = "Model VFX",
		Description = "Enable or disable your brainrot model VFX.",
	},
}

function PlayerSettingsConfig.GetDefinition(settingName)
	return PlayerSettingsConfig.ToggleDefinitions[settingName]
end

function PlayerSettingsConfig.GetToggleValue(settings, settingName)
	local definition = PlayerSettingsConfig.GetDefinition(settingName)
	if not definition then
		return nil
	end

	local value = settings and settings[settingName]
	if typeof(value) == "boolean" then
		return value
	end

	return definition.Default
end

function PlayerSettingsConfig.GetToggleSettings(settings)
	local values = {}

	for _, settingName in ipairs(PlayerSettingsConfig.ToggleOrder) do
		values[settingName] = PlayerSettingsConfig.GetToggleValue(settings, settingName)
	end

	return values
end

function PlayerSettingsConfig.ApplyPlayerAttributes(player, settings)
	if not player then
		return
	end

	for _, settingName in ipairs(PlayerSettingsConfig.ToggleOrder) do
		local definition = PlayerSettingsConfig.GetDefinition(settingName)
		player:SetAttribute(definition.Attribute, PlayerSettingsConfig.GetToggleValue(settings, settingName))
	end

	player:SetAttribute(PlayerSettingsConfig.LoadedAttribute, true)
end

function PlayerSettingsConfig.SetLoaded(player, value)
	if not player then
		return
	end

	player:SetAttribute(PlayerSettingsConfig.LoadedAttribute, value == true)
end

return PlayerSettingsConfig
