local Players = game:GetService("Players")
local RP = game:GetService("ReplicatedStorage")
local ServiceFolder = RP:WaitForChild("MyService")
local myServices = require(ServiceFolder:WaitForChild("MyService"))
local GameConfig = require(RP:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local PlayerSettingsConfig = require(RP:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("PlayerSettingsConfig"))

local player = Players.LocalPlayer

local SettingsManager = {}
local ServiceTable = {}
local currentSkipBrainrot = 0
local DEFAULT_WAIT_TIMEOUT = GameConfig.Shared.DefaultWaitTimeout
local ENABLED_COLOR = Color3.fromRGB(85, 255, 127)
local DISABLED_COLOR = Color3.fromRGB(255, 95, 95)

local function disconnectConnections(connectionList)
	for _, connection in ipairs(connectionList) do
		connection:Disconnect()
	end

	table.clear(connectionList)
end

local function sanitizeNumberText(textBox)
	textBox.Text = textBox.Text:gsub("%D", "")
end

local function createTextLabel(name, text, size, position, textTransparency)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextTransparency = textTransparency or 0

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = name == "Description" and 18 or 24
	constraint.MinTextSize = 1
	constraint.Parent = label

	return label
end

local function styleToggleButton(button, enabled)
	button.Text = enabled and "ON" or "OFF"
	button.BackgroundColor3 = enabled and ENABLED_COLOR or DISABLED_COLOR
end

function SettingsManager:SetToggleValue(settingName, value)
	local enabled = value == true
	self.ToggleValues[settingName] = enabled

	local control = self.ToggleControls[settingName]
	if control and control.Button then
		styleToggleButton(control.Button, enabled)
	end
end

function SettingsManager:EnsureToggleControl(settingName, order)
	if self.ToggleControls[settingName] and self.ToggleControls[settingName].Frame.Parent == self.Container then
		return self.ToggleControls[settingName]
	end

	local definition = PlayerSettingsConfig.GetDefinition(settingName)
	if not definition then
		return nil
	end

	local sample = self.Container:FindFirstChild("SkipBrainrot")
	local frame = Instance.new("Frame")
	frame.Name = string.format("Toggle_%02d_%s", order, settingName)
	frame.BackgroundTransparency = 1
	frame.LayoutOrder = order
	frame.Size = sample and sample.Size or UDim2.new(0.5, 0, 0.1, 0)
	frame.Parent = self.Container

	local title = createTextLabel("Title", definition.Label, UDim2.new(0.62, 0, 0.36, 0), UDim2.new(0.03, 0, 0.18, 0))
	title.Parent = frame

	local description = createTextLabel(
		"Description",
		definition.Description,
		UDim2.new(0.62, 0, 0.38, 0),
		UDim2.new(0.03, 0, 0.54, 0),
		0.2
	)
	description.Parent = frame

	local button = Instance.new("TextButton")
	button.Name = "Toggle"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.AutoButtonColor = false
	button.BackgroundColor3 = DISABLED_COLOR
	button.Position = UDim2.new(0.96, 0, 0.5, 0)
	button.Size = UDim2.new(0.24, 0, 0.7, 0)
	button.Font = Enum.Font.FredokaOne
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextScaled = true
	button.Text = "OFF"
	button.Parent = frame

	local buttonConstraint = Instance.new("UITextSizeConstraint")
	buttonConstraint.MaxTextSize = 22
	buttonConstraint.MinTextSize = 1
	buttonConstraint.Parent = button

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0.18, 0)
	buttonCorner.Parent = button

	local buttonStroke = Instance.new("UIStroke")
	buttonStroke.Color = Color3.fromRGB(255, 255, 255)
	buttonStroke.Thickness = 2
	buttonStroke.Transparency = 0.25
	buttonStroke.Parent = button

	local control = {
		Frame = frame,
		Button = button,
	}

	self.ToggleControls[settingName] = control

	table.insert(self.Connections, button.MouseButton1Click:Connect(function()
		self:ToggleSetting(settingName)
	end))

	return control
end

function SettingsManager:EnsureToggleControls()
	local skipBrainrot = self.Container and self.Container:FindFirstChild("SkipBrainrot")
	if skipBrainrot then
		skipBrainrot.LayoutOrder = 100
	end

	for index, settingName in ipairs(PlayerSettingsConfig.ToggleOrder) do
		self:EnsureToggleControl(settingName, index)
	end
end

function SettingsManager:RefreshToggleValues()
	local settings = ServiceTable["RemoteEvent"]:InvokeServer("GetInfo", "GetClientSettings")
	if typeof(settings) ~= "table" then
		return
	end

	for _, settingName in ipairs(PlayerSettingsConfig.ToggleOrder) do
		self:SetToggleValue(settingName, settings[settingName])
	end
end

function SettingsManager:ToggleSetting(settingName)
	local nextValue = not (self.ToggleValues[settingName] == true)
	local success, value = ServiceTable["RemoteEvent"]:InvokeServer("GetInfo", "UpdateClientSetting", settingName, nextValue)

	if success then
		self:SetToggleValue(settingName, value)
	end
end

function SettingsManager:Visible()
	table.insert(self.Connections, self.LeftButtons.Settings.MouseButton1Click:Connect(function()
		ServiceTable["Gui"]:AnimFrame(self.SettingsFrame, not self.SettingsFrame.Visible)
	end))

	table.insert(self.Connections, self.Background.X.MouseButton1Click:Connect(function()
		ServiceTable["Gui"]:AnimFrame(self.SettingsFrame, false)
	end))
end

function SettingsManager:RefreshSkipBrainrot()
	local skipBrainrot = self.Container:FindFirstChild("SkipBrainrot")
	if not skipBrainrot then
		return
	end

	local count = ServiceTable["RemoteEvent"]:InvokeServer("GetInfo", "GetSkipBrairot")
	if count ~= nil then
		skipBrainrot.Text = tostring(count)
		currentSkipBrainrot = count
	end
end

function SettingsManager:SaveSkipBrainrot()
	local skipBrainrot = self.Container:FindFirstChild("SkipBrainrot")
	if not skipBrainrot then
		return
	end

	local count = 0
	if skipBrainrot.Text ~= "" then
		count = tonumber(skipBrainrot.Text) or 0
	end

	if count ~= currentSkipBrainrot then
		ServiceTable["RemoteEvent"]:InvokeServer("GetInfo", "UpdateSkipBrairot", count)
		currentSkipBrainrot = count
	end
end

function SettingsManager:Load()
	local skipBrainrot = self.Container:FindFirstChild("SkipBrainrot")
	if not skipBrainrot then
		return
	end

	self:EnsureToggleControls()
	sanitizeNumberText(skipBrainrot)

	table.insert(self.Connections, skipBrainrot:GetPropertyChangedSignal("Text"):Connect(function()
		sanitizeNumberText(skipBrainrot)
	end))

	table.insert(self.Connections, self.SettingsFrame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not self.SettingsFrame.Visible then
			self:SaveSkipBrainrot()
			return
		end

		self:RefreshSkipBrainrot()
		self:RefreshToggleValues()
	end))
end

function SettingsManager:BindGui()
	local MainGui = ServiceTable["Gui"]:WaitForGuiByName("MainGui", DEFAULT_WAIT_TIMEOUT)
	if not MainGui then
		return false
	end

	if self.MainGui == MainGui and self.SettingsFrame and self.SettingsFrame.Parent then
		return true
	end

	disconnectConnections(self.Connections)

	self.MainGui = MainGui
	self.SettingsFrame = self.MainGui:WaitForChild("SettingsFrame")
	self.Background = self.SettingsFrame:WaitForChild("Background")
	self.Container = self.Background:WaitForChild("Container")
	self.LeftButtons = self.MainGui:WaitForChild("LeftButtons")
	self.ToggleControls = {}
	self.ToggleValues = self.ToggleValues or {}

	self:Visible()
	self:Load()
	self:RefreshSkipBrainrot()
	self:RefreshToggleValues()

	return true
end

function SettingsManager:ScheduleBind()
	task.spawn(function()
		for _ = 1, 30 do
			if self:BindGui() then
				return
			end

			task.wait(0.2)
		end
	end)
end

function SettingsManager:Init()
	ServiceTable["RemoteEvent"] = myServices:LoadService("RemoteEvent") or myServices:GetService("RemoteEvent")
	ServiceTable["Gui"] = myServices:LoadService("Gui") or myServices:GetService("Gui")

	self.Connections = self.Connections or {}
	self.ToggleValues = self.ToggleValues or {}

	if not self.Initialized then
		self.Initialized = true
		player.CharacterAdded:Connect(function()
			self:ScheduleBind()
		end)
	end

	self:ScheduleBind()
end

return SettingsManager
