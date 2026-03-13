local Players = game:GetService("Players")
local RP = game:GetService("ReplicatedStorage")
local TS = game:GetService('TweenService')
local DebrisService = game:GetService("Debris")

local myServices = require(RP:WaitForChild("MyService"):WaitForChild("MyService"))
local BrainrotSoundPlayer = require(RP:WaitForChild("Module"):WaitForChild("BrainrotSoundPlayer"))
local ViewPortModule = require(RP:WaitForChild("Module"):WaitForChild("ViewPortModule"))
local TextModule = require(RP:WaitForChild("Module"):WaitForChild("TextModule"))
local MessageModule = require(RP:WaitForChild("Module"):WaitForChild("MessageModule"))
local PreviewModel = require(RP:WaitForChild("Module"):WaitForChild("PreviewModel"))
local AnimationRoll = require(script:WaitForChild("AnimationRoll"))


local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()

local IsRoll = false
local debounce = false

local RollManager = {}
local ServiceTable = {}
local selectionConnections = {}
local uiConnections = {}

local Settings = {
	ButtonInfo = TweenInfo.new(.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
	Roll = TweenInfo.new(.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),

	Size = {
		Origin = UDim2.new(0.2,0,0.7,0),
		Target = UDim2.new(0.25,0,0.75,0),
	},
	AutoRoll = false,
	FastRoll = false,
	
}

local ToggleConfigs = {
	AutoRoll = {
		key = "AutoRoll",
		label = "AUTO ROLL",
	},
	FastRoll = {
		key = "FastRoll",
		label = "FAST ROLL",
		requirePurchase = true,
	},
}

local function GetAnimation()
	return RP:WaitForChild("animation"):WaitForChild("Idle"):WaitForChild("Idle6")
end

local function SetToggleLabel(label, text, state)
	if not label then
		return
	end

	label.RichText = true
	label.Text = string.format(
		"%s: <font color='rgb(%d,%d,%d)'>%s</font>",
		text,
		state and 0 or 255,
		state and 255 or 0,
		0,
		state and "ON" or "OFF"
	)
end

local function Visible(value)
	local RollGui = ServiceTable["RollGui"] if not RollGui then return end
	local MainGui = ServiceTable["Gui"]:GetGuiByName("MainGui")
	local RollFrame = RollGui:WaitForChild("RollFrame")
	local ButtonFrame = RollGui:WaitForChild("ButtonFrame")

	MainGui.Enabled = not value
	RollFrame.Visible = value
	RollGui.Affiche.Visible = not value
	IsRoll = value
	ButtonFrame.Visible = not value

end

local function Roll(number)
	local RollGui = ServiceTable["RollGui"]
	if char:GetAttribute("Grab") then return end
	if not IsRoll then
		local Succes, mess = ServiceTable["RemoteEvent"]:InvokeServer("RollFonction", "CanRoll")
		
		if mess then
			MessageModule:SendMessage(player, mess, 2, Color3.fromRGB(255, 0, 0))
		end
		
		if Succes then
			IsRoll = true
			Visible(true)
			RollManager:CreateTemplate(number)
		end
		
		
		
	end
end

local function DisconnectSelectionConnections()
	for _, connection in pairs(selectionConnections) do
		if connection then
			connection:Disconnect()
		end
	end

	table.clear(selectionConnections)
end

local function DisconnectUiConnections()
	for _, connection in ipairs(uiConnections) do
		connection:Disconnect()
	end

	table.clear(uiConnections)
end

local function ClearSelection()
	ServiceTable["RemoteEvent"]:InvokeServer("RollFonction", "ClearSelection")
end

player.CharacterAdded:Connect(function(newCharacter)
	char = newCharacter
	IsRoll = false
	DisconnectSelectionConnections()
	PreviewModel:Clear("RollSelection")

	if RollManager.Initialized then
		RollManager:ScheduleBind()
	end
end)

function RollManager:AnimateButton()
	local RollGui = ServiceTable.RollGui or ServiceTable.Gui:GetGuiByName("RollGui")
	if not RollGui then return end

	local ButtonFrame = RollGui:WaitForChild("ButtonFrame")

	local function animate(frame, size)
		TS:Create(frame, Settings.ButtonInfo, { Size = size }):Play()
	end

	for _, frame in ipairs(ButtonFrame:GetChildren()) do
		if not frame:IsA("Frame") then continue end

		local button = frame.Button
		local label = button:FindFirstChild("TitleLabel")
		local config = ToggleConfigs[frame.Name]

		table.insert(uiConnections, button.MouseEnter:Connect(function()
			animate(frame, Settings.Size.Target)
		end))

		table.insert(uiConnections, button.MouseLeave:Connect(function()
			animate(frame, Settings.Size.Origin)
		end))

		table.insert(uiConnections, button.MouseButton1Click:Connect(function()
			if frame.Name == "Roll" then
				
				if char:GetAttribute("CurrentZone") == "SafeZone" then
					Roll(Settings.FastRoll and 3 or 7)
					return
				else
					MessageModule:SendMessage(player, "You can't roll outside the safe zone !", 2, Color3.new(1,0,0))
				end
				return
			end

			if not config then return end

			if config.requirePurchase and ServiceTable.MarketPlaceService then
				local succes, value = ServiceTable["RemoteEvent"]:InvokeServer("RollFonction", config.key)
				if succes then
					if value ~= nil then
						Settings[config.key] = value
					end
				else
					if not ServiceTable.MarketPlaceService:Purchase(player, frame.Name) then
						if value ~= nil then
							Settings[config.key] = value
						end
					end
				end
			end
			
			if config.key == "AutoRoll" then
				local succes, value = ServiceTable["RemoteEvent"]:InvokeServer("RollFonction", "AutoRoll")
				
				if succes then
					Settings[config.key] = value
				else
					MessageModule:SendMessage(player, "Join the group or reach 100 rolls to use auto roll !", 2, Color3.new(1,0,0))
				end
				
			end

			
			self:RefreshToggleButtons()
			--ChangeData()
		end))

	end

	self:RefreshToggleButtons()
end

function RollManager:BindGui()
	local RollGui = ServiceTable["Gui"]:WaitForGuiByName("RollGui", 15)
	if not RollGui then
		return false
	end

	if ServiceTable["RollGui"] == RollGui and RollGui.Parent then
		self:ApplyButtonInfo()
		return true
	end

	DisconnectUiConnections()
	DisconnectSelectionConnections()

	ServiceTable["RollGui"] = RollGui
	self:ApplyButtonInfo()
	self:AnimateButton()

	return true
end

function RollManager:ScheduleBind()
	task.spawn(function()
		for _ = 1, 30 do
			if self:BindGui() then
				return
			end

			task.wait(0.2)
		end
	end)
end

function RollManager:ApplyButtonInfo()
	local auto, fast = ServiceTable["RemoteEvent"]:InvokeServer("GetInfo", "Roll")
	
	Settings.AutoRoll = auto or false
	Settings.FastRoll = fast or false
	self:RefreshToggleButtons()
end

function RollManager:RefreshToggleButtons()
	local RollGui = ServiceTable.RollGui or (ServiceTable.Gui and ServiceTable.Gui:GetGuiByName("RollGui"))
	if not RollGui then
		return
	end

	local ButtonFrame = RollGui:FindFirstChild("ButtonFrame")
	if not ButtonFrame then
		return
	end

	for frameName, config in pairs(ToggleConfigs) do
		local frame = ButtonFrame:FindFirstChild(frameName)
		local button = frame and frame:FindFirstChild("Button")
		local label = button and button:FindFirstChild("TitleLabel")

		if label then
			SetToggleLabel(label, config.label, Settings[config.key])
		end
	end
end

function RollManager:CreateTemplate(number)
	local RollGui = ServiceTable["RollGui"] if not RollGui then return end
	local RollFrame = RollGui:WaitForChild("RollFrame")
	local BaseFrame = RollFrame:WaitForChild("Asset"):WaitForChild("Base")
	local RollSelect = RollGui:WaitForChild("RollSelect")

	local Button_Frame = RollSelect.Base.Asset.Button
	local Desactive = RollSelect.Base.Desactive

	for _, v in pairs(BaseFrame:GetChildren()) do
		if v:IsA("Frame") then
			v:Destroy()
		end
	end

	BrainrotSoundPlayer:StopAll()

	local RollTable, result, _, Skipded = ServiceTable["RemoteEvent"]:InvokeServer("RollFonction", "Roll", number)
	
	if RollTable == nil then
		IsRoll = false
		Visible(false)
		MessageModule:SendMessage(player, "Base full !", 2, Color3.new(1,0,0))
		return
	end
	
	if RollTable and result then
		
		AnimationRoll:Start(RollFrame)
		
		for i, brainrot in pairs(RollTable) do
			local Template = RollFrame:WaitForChild("Asset"):WaitForChild("Template"):Clone()
			Template.Name = tostring(i)
			Template.Label.Text = brainrot.Data.DisplayName
			Template.Visible = true
			Template.Parent = BaseFrame
			
			ServiceTable["Gui"]:LabelColor(Template.Label, brainrot.Data.Rarity)
			
			local Tween = TS:Create(
				Template.Label,
				Settings.Roll,
				{ Position = UDim2.new(0, 0, 0, 0) }
			)
			Tween:Play()
			
			Tween.Completed:Wait()
			Template:Destroy()
		end
		
		AnimationRoll:Stop(RollFrame)
		
		RollFrame.Visible = false
		
		if Skipded then
			RollSelect.Visible = false
			Visible(false)
			ClearSelection()
			PreviewModel:Clear("RollSelection")

			if Settings.AutoRoll and not debounce then
				debounce = true
				task.wait(.1)
				debounce = false
				Roll(Settings.FastRoll and 3 or 7)
			end
			return
		end
		
		RollSelect.Visible = true
		DisconnectSelectionConnections()
		BrainrotSoundPlayer:Play(result)
		
		local Model = PreviewModel:GetModel("RollSelection", result.Name, result.Mutation)
		local ViewPort = nil
		
		if Model then
			Model.Parent = workspace
			ViewPort = ViewPortModule.new(
				Model,
				RollSelect.Base.ViewportFrame
			)
			ViewPort:Start()
		end

		RollManager.InfoSet(
			RollSelect.Base.InfoFrame,
			result.Data,
			result.Mutation,
			result.Multiplicateur or 1
		)
		
		for _, v in pairs(RollSelect.Base.SFR:GetChildren()) do
			if v:IsA("Frame") then
				v:Destroy()
			end
		end
		
		for i = 1, result.Slots do
			local SlotTemplate = RollSelect.Base.Template:Clone()
			SlotTemplate.Parent = RollSelect.Base.SFR
			SlotTemplate.Visible = true
			SlotTemplate.Name = "Clone"
		end
		
		Desactive.Visible = Settings.AutoRoll	
		
		selectionConnections.Buy = Button_Frame.Buy.Button.MouseButton1Click:Connect(function()
			local succes, message = ServiceTable["RemoteEvent"]:InvokeServer("RollFonction", "Buy")
			
			if succes then
				BrainrotSoundPlayer:StopAll()
				RollSelect.Visible = false
				Visible(false)
				if ViewPort then
					ViewPort:Destroy()
				end
				ClearSelection()
				PreviewModel:Clear("RollSelection")
			end
			
			if message then self.Mess(RollSelect.Base, message, 2) end
			
		end)
		
		selectionConnections.Cancel = Button_Frame.Cancel.Button.MouseButton1Click:Connect(function()
			RollSelect.Visible = false
			Visible(false)
			if ViewPort then
				ViewPort:Destroy()
			end
			ClearSelection()
			PreviewModel:Clear("RollSelection")

			if Settings.AutoRoll and not debounce then
				debounce = true
				Roll(Settings.FastRoll and 3 or 7)
				task.delay(.1, function() debounce = false end)
			end

		end)

		selectionConnections.Desactive = Desactive.Button.MouseButton1Click:Connect(function()
			local succes, value = ServiceTable["RemoteEvent"]:InvokeServer("RollFonction", "DesactiveAutoRoll")
			
			if succes then
				Settings.AutoRoll = value
				Desactive.Visible = false
				self:RefreshToggleButtons()
			end
			
		end)
		
		---------------------------
	else
		MessageModule:SendMessage(player, "Base full !", 2, Color3.new(1,0,0))
	end
	
end

function RollManager.InfoSet(FrameInfo, infoData, MutaSelect, multiplicated)
	if infoData then
		local CashPerSeconde = tonumber(infoData.CashPerSeconde) * multiplicated
		FrameInfo.Title.Text = infoData.DisplayName
		FrameInfo.Rarity.Text = infoData.Rarity
		FrameInfo.CashPerSeconde.Text = TextModule:Suffixe(CashPerSeconde).." $"
		FrameInfo.CashRequire.Text = TextModule:Suffixe(infoData.Price).." $"

		if MutaSelect and MutaSelect ~= "Normal" then
			FrameInfo.Mutation.Visible = true
			FrameInfo.Mutation.Text = MutaSelect
			ServiceTable["Gui"]:LabelColor(FrameInfo.Mutation, MutaSelect)
		else
			FrameInfo.Mutation.Visible = false
			FrameInfo.Mutation.Text = ""
		end

		ServiceTable["Gui"]:LabelColor(FrameInfo.Rarity, infoData.Rarity)
	else
		warn("Pas Info data")
	end
end

function RollManager.Mess(Base, Mess, lifeTime)
	local MessFrame = Base:WaitForChild("MessFrame")
	local Template = MessFrame:WaitForChild("Template"):Clone()
	Template.Text = Mess
	Template.Visible = true
	Template.Parent = MessFrame

	Template.TextTransparency = 1
	Template.UIStroke.Transparency = 1

	TS:Create(Template, TweenInfo.new(.15), {TextTransparency = 0}):Play()
	TS:Create(Template:WaitForChild("UIStroke"), TweenInfo.new(.15), {Transparency = 0}):Play()

	DebrisService:AddItem(Template, lifeTime)
end

function RollManager:Init()
	ServiceTable["Gui"] = myServices:LoadService("Gui") or myServices:GetService("Gui")
	ServiceTable["RemoteEvent"] = myServices:LoadService("RemoteEvent") or myServices:GetService("RemoteEvent")
	ServiceTable["MarketPlaceService"] = myServices:LoadService("MarketPlaceService") or myServices:GetService("MarketPlaceService")

	self.Initialized = true
	self:ScheduleBind()

end

return RollManager
