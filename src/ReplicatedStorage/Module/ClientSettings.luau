local Players = game:GetService("Players")
local RP = game:GetService("ReplicatedStorage")

local PlayerSettingsConfig = require(RP:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("PlayerSettingsConfig"))

local ClientSettings = {}
local LocalPlayer = Players.LocalPlayer

local function getDefinition(settingName)
	return PlayerSettingsConfig.GetDefinition(settingName)
end

function ClientSettings:IsLoaded()
	return LocalPlayer:GetAttribute(PlayerSettingsConfig.LoadedAttribute) == true
end

function ClientSettings:WaitUntilLoaded(timeout)
	local deadline = os.clock() + (timeout or 10)

	while LocalPlayer.Parent and not self:IsLoaded() and os.clock() < deadline do
		task.wait(0.1)
	end

	return self:IsLoaded()
end

function ClientSettings:GetToggle(settingName)
	local definition = getDefinition(settingName)
	if not definition then
		return nil
	end

	local value = LocalPlayer:GetAttribute(definition.Attribute)
	if typeof(value) == "boolean" then
		return value
	end

	return definition.Default
end

function ClientSettings:ObserveToggle(settingName, callback, immediate)
	local definition = getDefinition(settingName)
	if not definition then
		error(`Unknown client setting "{tostring(settingName)}"`, 2)
	end

	if immediate ~= false then
		callback(self:GetToggle(settingName))
	end

	return LocalPlayer:GetAttributeChangedSignal(definition.Attribute):Connect(function()
		callback(self:GetToggle(settingName))
	end)
end

return ClientSettings
