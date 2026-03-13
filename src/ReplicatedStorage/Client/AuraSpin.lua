local RP = game:GetService("ReplicatedStorage")
local myServices = require(RP:WaitForChild("MyService"):WaitForChild("MyService"))
local TS = game:GetService("TweenService")
local RS = game:GetService("RunService")

local ViewPortModule = require(RP.Module.ViewPortModule)
local TextModule = require(RP.Module.TextModule)
local GuiList = require(RP.List.GuiList)
local PreviewModel = require(RP:WaitForChild("Module"):WaitForChild("PreviewModel"))
local ClientSettings = require(RP:WaitForChild("Module"):WaitForChild("ClientSettings"))
local ModelVFX = require(RP:WaitForChild("Module"):WaitForChild("ModelVFX"))

local AuraSpin = {}
local ServiceTable = {}
local Connection = {}
local closeButtonConnection
local rollButtonConnection
local preview = nil
local OldNumber = 0
local db = false
local currentCash = 0
local currentModel = nil
local currentSlots = {}
local modelVfxEnabled = ClientSettings:GetToggle("ModelVFXEnabled")

local function InitService()
	if not ServiceTable.Gui or not ServiceTable.RemoteEvent then
		ServiceTable.Gui = myServices:LoadService("Gui") or myServices:GetService("Gui")
		ServiceTable.RemoteEvent = myServices:LoadService("RemoteEvent") or myServices:GetService("RemoteEvent")
	end
end

local function Round2(n)
	return math.floor(n * 100 + 0.5) / 100
end

local function cloneSlots(slots)
	local cloned = {}

	for key, value in pairs(slots or {}) do
		cloned[key] = value
	end

	return cloned
end

local function refreshCurrentModelVfx()
	if not currentModel then
		return
	end

	if not modelVfxEnabled then
		ModelVFX.ClearAura(currentModel)
		return
	end

	ModelVFX.ApplyAuraList(currentModel, currentSlots)
end

local function setCurrentAuraSlots(slots)
	currentSlots = cloneSlots(slots)

	if currentModel then
		refreshCurrentModelVfx()
	end
end

ClientSettings:ObserveToggle("ModelVFXEnabled", function(value)
	modelVfxEnabled = value == true
	refreshCurrentModelVfx()
end)

local function AnimateCash(label, oldCash, newCash)
	if newCash > oldCash then
		label.TextColor3 = Color3.fromRGB(85, 255, 0)
	elseif newCash < oldCash then
		label.TextColor3 = Color3.fromRGB(255, 42, 63)
	else
		return
	end

	local value = Instance.new("NumberValue")
	value.Value = oldCash

	value:GetPropertyChangedSignal("Value"):Connect(function()
		label.Text = TextModule:Suffixe(Round2(value.Value)) .. " $"
	end)

	local tween =
		TS:Create(value, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = newCash })

	tween:Play()
	tween.Completed:Wait()

	currentCash = newCash
	label.TextColor3 = Color3.fromRGB(85, 255, 127)
	value:Destroy()
end

local function AnimRoll(Template, AuraList, AuraSelect, Frame)
	for _, v in pairs(Template.Asset:GetChildren()) do
		if v:IsA("Frame") then
			v:Destroy()
		end
	end

	Template.Icon.Visible = false

	local duration = 10

	for i, value in ipairs(AuraList) do
		if not Frame.Visible then
			break
		end

		local Anim = Template.Anim:Clone()
		Anim.Visible = true
		Anim.Parent = Template.Asset
		Anim.Icon.Image = GuiList.Settings.rtbx .. value.ImageId

		if i == 7 then
			TS:Create(
				Anim.Icon,
				TweenInfo.new(0.175, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
				{ Position = UDim2.new(0, 0, 0, 0) }
			):Play()
			Anim.Icon.Image = GuiList.Settings.rtbx .. AuraSelect.ImageId
			Anim.Visible = true
			task.delay(0.35, function()
				Anim:Destroy()
			end)
		end

		local tween = TS:Create(
			Anim.Icon,
			TweenInfo.new(0.35, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
			{ Position = UDim2.new(0, 0, 1, 0) }
		)

		if i < 7 then
			tween:Play()
			tween.Completed:Wait()
			Anim:Destroy()
		end
	end

	task.delay(0.35, function()
		Template.Icon.Visible = true

		if AuraSelect.ImageId ~= 0 then
			Template.Icon.Image = GuiList.Settings.rtbx .. AuraSelect.ImageId
			Template.Label.Text = ""
		else
			Template.Label.Text = AuraSelect.Name
		end
	end)

	return duration
end

local function ClearSlotFrames(background)
	for _, v in pairs(background.SFR:GetChildren()) do
		if v:IsA("Frame") and v.Name ~= "Template" then
			v:Destroy()
		end
	end
end

local function SetEmptyState(background, auraSpinFrame)
	if preview then
		preview:Destroy()
		preview = nil
	end

	PreviewModel:Clear("AuraSpinSelection")

	background.Title.Text = "Place a brainrot"
	background.Price.Text = "Into the machine"
	background.Rarity.Text = "Carry one from your base"
	background.Mutation.Text = "Then open Aura Spin"
	background.CashPerSeconde.Text = "0 $"
	currentCash = 0
	currentSlots = {}

	ClearSlotFrames(background)

	auraSpinFrame.RollButton.Visible = true
	auraSpinFrame.RollButton.Button.Text = 'Roll <font color="rgb(255,120,120)">(Load a brainrot first)</font>'
end

function AuraSpin:Init(player, ...)
	InitService()
	local Halls = { ... }
	local EventType = Halls[1]

	local MainGui = ServiceTable.Gui:GetGuiByName("MainGui")
	local RollGui = ServiceTable.Gui:GetGuiByName("RollGui")
	local AuraSpinFrame = MainGui.AuraSpin
	local Background = AuraSpinFrame.Background

	if EventType == "Visible" then
		RollGui.Enabled = AuraSpinFrame.Visible
		ServiceTable.Gui:AnimFrame(AuraSpinFrame, not AuraSpinFrame.Visible)
		SetEmptyState(Background, AuraSpinFrame)

		if closeButtonConnection then
			closeButtonConnection:Disconnect()
		end

		closeButtonConnection = Background.X.MouseButton1Click:Connect(function()
			ServiceTable.Gui:AnimFrame(AuraSpinFrame, false)
			RollGui.Enabled = true
			PreviewModel:Clear("AuraSpinSelection")
		end)

		if rollButtonConnection then
			rollButtonConnection:Disconnect()
		end

		rollButtonConnection = AuraSpinFrame.RollButton.Button.MouseButton1Click:Connect(function()
			if not db then
				db = true

				local succes, mess, results, NewCash =
					ServiceTable["RemoteEvent"]:InvokeServer("AuraSpin", "RollAll")

				if succes == nil then
					db = false
					AuraSpinFrame.RollButton.Visible = true
					return
				end

				if succes then
					AuraSpinFrame.RollButton.Visible = false

					for slotName, data in pairs(results or {}) do
						if data and data.Result and data.Result.Name then
							currentSlots[slotName] = data.Result.Name
						end
					end

					if currentModel then
						refreshCurrentModelVfx()
					end

					for slotName, data in pairs(results) do
						task.spawn(function()
							local template = Background.SFR:FindFirstChild(slotName)
							if template then
								template.Label.Text = ""

								task.spawn(function()
									AnimRoll(template, data.AuraList, data.Result, AuraSpinFrame)
								end)
							end
						end)
					end

					task.delay(2.45, function()
						AnimateCash(Background.CashPerSeconde, currentCash, NewCash)
						db = false
						AuraSpinFrame.RollButton.Visible = true
					end)
				else
					db = false
					AuraSpinFrame.RollButton.Visible = true
				end
			end
		end)
		return true
	elseif EventType == "Update" or EventType == "UpdateInfo" then
		local Name, Mutation, Rarity, CashPerSeconde, Price, Slots, CashRequire =
			Halls[2], Halls[3], Halls[4], Halls[5], Halls[6], Halls[7], Halls[8]

		AuraSpinFrame.RollButton.Button.Text = 'Roll <font color="rgb(85,255,127)">('
			.. TextModule:Suffixe(Round2(CashRequire))
			.. " $)</font>"

		local BrairotModel = PreviewModel:GetModel("AuraSpinSelection", Name, Mutation)

		if BrairotModel then
			if preview then
				preview:Destroy()
			end
			preview = ViewPortModule.new(BrairotModel, Background.ViewportFrame)
			preview:Start()
		end

		Background.Title.Text = Name
		Background.Price.Text = TextModule:Suffixe(Price) .. " $"
		Background.Rarity.Text = Rarity
		Background.Mutation.Text = Mutation
		Background.CashPerSeconde.Text = TextModule:Suffixe(CashPerSeconde) .. " $"
		currentCash = CashPerSeconde
		setCurrentAuraSlots(Slots)

		if EventType == "Update" then
			ClearSlotFrames(Background)
		end

		for names, value in pairs(Slots) do
			local Template = nil

			if EventType == "Update" then
				Template = Background.Template:Clone()
			else
				Template = Background.SFR:FindFirstChild(names)
			end

			if Template == nil then
				Template = Background.Template:Clone()
			end

			local AuraInfo = ServiceTable.RemoteEvent:InvokeServer("GetInfo", "AuraList", value)
			Template.Name = names
			Template.Parent = Background.SFR
			Template.Visible = true

			if AuraInfo then
				Template.Icon.Image = "rbxassetid://" .. AuraInfo.ImageId
				Template.Label.Text = ""
			else
				Template.Label.Text = value
			end
		end
	elseif EventType == "Empty" then
		SetEmptyState(Background, AuraSpinFrame)
	elseif EventType == "CashUpdate" then
		local Cash = Halls[2]
		currentCash = Cash
		Background.CashPerSeconde.Text = TextModule:Suffixe(Cash) .. " $"
	elseif EventType == "BrairotPreview" then
		if Halls[2] == true then
			game.Workspace.InteractFolder.AuraSpin.Place:ClearAllChildren()
			local BrairotModel = PreviewModel:GetModel("AuraSpinWorld", Halls[4], Halls[3])
			local Slots = Halls[5] or currentSlots

			currentModel = nil

			if BrairotModel then
				BrairotModel.Parent = game.Workspace.InteractFolder.AuraSpin.Place
				BrairotModel.PrimaryPart.Anchored = true
				BrairotModel:PivotTo(game.Workspace.InteractFolder.AuraSpin.Machine:WaitForChild("SpawnZone").CFrame)
				currentModel = BrairotModel
				setCurrentAuraSlots(Slots)
			end
		else
			if currentModel then
				ModelVFX.ClearAura(currentModel)
				currentModel:Destroy()
				currentModel = nil
			end
			currentSlots = {}
			PreviewModel:Clear("AuraSpinWorld")
		end
	end
end

local stepEvent = RS:IsServer() and RS.Heartbeat or RS.RenderStepped

table.insert(
	Connection,
	stepEvent:Connect(function(dt)
		if currentModel == nil then
			return
		end

		local currentPivot = currentModel:GetPivot()
		local rotation = CFrame.Angles(0, math.rad(30) * dt, 0)
		currentModel:PivotTo(currentPivot * rotation)
	end)
)

return AuraSpin
