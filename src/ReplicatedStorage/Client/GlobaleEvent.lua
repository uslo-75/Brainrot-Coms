local RP = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local myServices = require(RP:WaitForChild("MyService"):WaitForChild("MyService"))
local RS = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GlobaleEvent = {}
local Flying = {}
local BasePositions = {}
local localPlayer = Players.LocalPlayer

local amplitude = 2
local speed = 2
local flyUpdateAccumulator = 0
local FLY_UPDATE_INTERVAL = 1 / 30

local currentTimers = {}
local activeTransitionTweens = {}
local transitionToken = 0

local function cancelTransitionTweens()
	for _, tween in ipairs(activeTransitionTweens) do
		tween:Cancel()
	end

	table.clear(activeTransitionTweens)
end

local function ensureTransitionOverlay()
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui") or localPlayer:WaitForChild("PlayerGui")
	local screenGui = playerGui:FindFirstChild("MapTransitionGui")

	if not screenGui then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = "MapTransitionGui"
		screenGui.DisplayOrder = 1000
		screenGui.IgnoreGuiInset = true
		screenGui.ResetOnSpawn = false
		screenGui.Parent = playerGui
	end

	local flashFrame = screenGui:FindFirstChild("Flash")
	if not flashFrame then
		flashFrame = Instance.new("Frame")
		flashFrame.Name = "Flash"
		flashFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		flashFrame.Position = UDim2.fromScale(0.5, 0.5)
		flashFrame.Size = UDim2.fromScale(1, 1)
		flashFrame.BorderSizePixel = 0
		flashFrame.BackgroundColor3 = Color3.new(1, 1, 1)
		flashFrame.BackgroundTransparency = 1
		flashFrame.Visible = false
		flashFrame.Parent = screenGui
	end

	return flashFrame
end

local function playTransitionEffect()
	transitionToken += 1
	local currentToken = transitionToken
	local flashFrame = ensureTransitionOverlay()
	local transitionSound = SoundService:FindFirstChild("Sounds") and SoundService.Sounds:FindFirstChild("Transition")
	local soundDuration = 1.1

	if transitionSound and transitionSound:IsA("Sound") then
		if transitionSound.IsLoaded and transitionSound.TimeLength > 0 then
			soundDuration = transitionSound.TimeLength
		end

		transitionSound:Stop()
		transitionSound.TimePosition = 0
		transitionSound:Play()
	end

	cancelTransitionTweens()

	flashFrame.Visible = true
	flashFrame.BackgroundTransparency = 1

	local flashInTween = TweenService:Create(
		flashFrame,
		TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0.02 }
	)

	table.insert(activeTransitionTweens, flashInTween)
	flashInTween:Play()
	flashInTween.Completed:Wait()

	if currentToken ~= transitionToken then
		return
	end

	task.wait(0.08)
	if currentToken ~= transitionToken then
		return
	end

	local flashOutTween = TweenService:Create(
		flashFrame,
		TweenInfo.new(math.max(soundDuration + 0.25, 1.25), Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }
	)

	table.insert(activeTransitionTweens, flashOutTween)
	flashOutTween:Play()
	flashOutTween.Completed:Wait()

	if currentToken ~= transitionToken then
		return
	end

	flashFrame.Visible = false
end

local function getModelPivot(model)
	local success, pivot = pcall(function()
		return model:GetPivot()
	end)

	return success and pivot or nil
end

local function ensurePrimaryPart(model)
	if not (model and model:IsA("Model")) then
		return nil
	end

	local candidates = {
		model.PrimaryPart,
		model:FindFirstChild("RootPart", true),
		model:FindFirstChild("HumanoidRootPart", true),
		model:FindFirstChild("PrimaryPart", true),
		model:FindFirstChild("Hitbox", true),
		model:FindFirstChild("Head", true),
		model:FindFirstChildWhichIsA("BasePart", true),
	}

	for _, candidate in ipairs(candidates) do
		if candidate
			and candidate:IsA("BasePart")
			and candidate.Name ~= "PromptRoot"
			and candidate.Name ~= "SlotPromptRoot"
			and candidate.Name ~= "BrainrotPromptRoot"
			and candidate.Name ~= "DropPromptRoot"
			and candidate.Name ~= "GeneratedRootPart"
		then
			model.PrimaryPart = candidate
			return candidate
		end
	end

	return nil
end

local function isStockBrainrotModel(model)
	if not (model and model:IsA("Model")) then
		return false
	end

	if not ensurePrimaryPart(model) then
		return false
	end

	local slotModel = model.Parent
	if not (slotModel and slotModel:IsA("Model")) then
		return false
	end

	local stockFolder = slotModel.Parent
	if not (stockFolder and stockFolder.Name == "StockBrainrot") then
		return false
	end

	return true
end

local function stopFlyingModel(model)
	BasePositions[model] = nil

	for index = #Flying, 1, -1 do
		if Flying[index] == model then
			table.remove(Flying, index)
		end
	end
end

local function startFlyingModel(model)
	local primaryPart = ensurePrimaryPart(model)
	if not (model and primaryPart) then
		return
	end

	stopFlyingModel(model)
	table.insert(Flying, model)
	BasePositions[model] = getModelPivot(model) or primaryPart.CFrame
end

local function bootstrapExistingFlyingModels()
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if isStockBrainrotModel(descendant) then
			startFlyingModel(descendant)
		end
	end
end

local function startOrUpdateTimer(name, remainingTime, timeLabel)
	currentTimers[name] = (currentTimers[name] or 0) + 1
	local myTimerId = currentTimers[name]

	task.spawn(function()
		local timeLeft = remainingTime

		while timeLeft >= 0 do
			if myTimerId ~= currentTimers[name] then
				return
			end

			local hours = math.floor(timeLeft / 3600)
			local minutes = math.floor((timeLeft % 3600) / 60)
			local seconds = timeLeft % 60

			if hours <= 0 then
				timeLabel.Text = string.format("%02d:%02d", minutes, seconds)
			else
				timeLabel.Text = string.format("%02d:%02d:%02d", hours, minutes, seconds)
			end

			if timeLeft <= 0 then
				if timeLabel and timeLabel.Parent then
					timeLabel.Parent:Destroy()
				end
				break
			end

			task.wait(1)
			timeLeft -= 1
		end
	end)
end

function GlobaleEvent:Init(player, ...)
	local Halls = { ... }
	local ClientType = Halls[1]
	local Gui = myServices:LoadService("Gui") or myServices:GetService("Gui")
	local MainGui = Gui:GetGuiByName("MainGui")
	local EventFrame = MainGui.EventFrame
	local RobuxShop = MainGui.RobuxShop

	if ClientType == "AddEvent" then
		local EventName = Halls[2]
		local EventTime = Halls[3]

		local Template = EventFrame:FindFirstChild(EventName)

		if not Template then
			Template = EventFrame.Template:Clone()
			Template.Parent = EventFrame
			Template.Visible = true
			Template.Name = EventName
		end

		startOrUpdateTimer(EventName, EventTime, Template.TimeLabel)
	elseif ClientType == "ServerLuck" then
		local Text1 = Halls[2]
		local Text2 = Halls[3]
		local Color1 = Halls[4] or Color3.new(1, 1, 1)
		local Color2 = Halls[5] or Color3.new(1, 1, 1)

		if Text1 and Text2 then
			local ServerLuckFrame = RobuxShop.Background.Container.ServerLuck
			ServerLuckFrame.Deal.CurrentMultiplier.Text = Text1
			ServerLuckFrame.Deal.FinalMultiplier.Text = Text2

			ServerLuckFrame.Deal.FinalMultiplier.TextColor3 = Color2
			ServerLuckFrame.Deal.CurrentMultiplier.TextColor3 = Color1
		end
	elseif ClientType == "MapTransition" then
		task.spawn(playTransitionEffect)
	elseif ClientType == "FlyBrainrot" then
		local Model: Model = Halls[2]

		startFlyingModel(Model)
	elseif ClientType == "StopFlyBrainrot" then
		local Model: Model = Halls[2]

		stopFlyingModel(Model)
	elseif EventFrame == "Init" then
	end
end

RS.Heartbeat:Connect(function(dt)
	flyUpdateAccumulator += dt
	if flyUpdateAccumulator < FLY_UPDATE_INTERVAL then
		return
	end

	flyUpdateAccumulator = 0

	for index = #Flying, 1, -1 do
		local Model = Flying[index]
		local primaryPart = ensurePrimaryPart(Model)
		if Model and Model.Parent and primaryPart and BasePositions[Model] then
			local time = os.clock() * speed

			local offset = ((math.sin(time) + 1) / 2) * amplitude

			Model:PivotTo(BasePositions[Model] * CFrame.new(0, offset, 0))
		else
			stopFlyingModel(Model)
		end
	end
end)

Workspace.DescendantAdded:Connect(function(descendant)
	if isStockBrainrotModel(descendant) then
		task.defer(function()
			startFlyingModel(descendant)
		end)
	end
end)

task.defer(bootstrapExistingFlyingModels)

return GlobaleEvent
