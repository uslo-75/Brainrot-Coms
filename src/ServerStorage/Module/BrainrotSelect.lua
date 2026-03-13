local RP = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local BrainrotModel = ServerStorage:FindFirstChild("BrainrotModel") or RP:WaitForChild("BrainrotModel")
local RunService = game:GetService("RunService")
local TS = game:GetService("TweenService")

local GuiFolder = RP:WaitForChild("Gui")
local GlobalEvent = RP:WaitForChild("Events"):WaitForChild("RemoteEvents"):WaitForChild("GlobaleEvent")

local BrainrotList = require(ServerStorage.List.BrainrotList)
local GameConfig = require(RP:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local GuiList = require(RP.List.GuiList)
local TextModule = require(RP.Module.TextModule)
local MutationModule = require(ServerStorage.Module.RollModule.Mutation)
local AuraList = require(ServerStorage.List.AuraList)

local BrainrotSelect = {}
local BrainrotInfo = {}
local PlaceBrainrot = {}
local DroppedBrainrots = {}
local dropPromptConfig = GameConfig.Prompts.Drop

local BlackList = { "Spectral", "Solar", }
local DROP_PROMPT_ACTION = "Pick Up"
local DROP_FOLDER_NAME = "BrainrotDrops"

local connections = {}

local function Round2(n)
	return math.floor(n * 100 + 0.5) / 100
end

local function CloneTable(source)
	if typeof(source) ~= "table" then
		return source
	end

	local cloned = {}
	for key, value in pairs(source) do
		cloned[key] = value
	end

	return cloned
end

local function GetModelRootPart(model)
	if not model then
		return nil
	end

	local function IsUsableRootPart(candidate)
		return candidate
			and candidate:IsA("BasePart")
			and candidate.Name ~= "PromptRoot"
			and candidate.Name ~= "SlotPromptRoot"
			and candidate.Name ~= "BrainrotPromptRoot"
			and candidate.Name ~= "DropPromptRoot"
			and candidate.Name ~= "GeneratedRootPart"
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
		if IsUsableRootPart(candidate) then
			return candidate
		end
	end

	return nil
end

local function GetModelPivot(model)
	local success, pivot = pcall(function()
		return model:GetPivot()
	end)

	return success and pivot or CFrame.new()
end

local function WeldModelToRootPart(model, rootPart)
	if not model or not rootPart then
		return
	end

	for _, weld in ipairs(rootPart:GetChildren()) do
		if weld:IsA("WeldConstraint") and weld.Name == "GeneratedRootWeld" then
			weld:Destroy()
		end
	end

	local connectedLookup = {}
	local adjacency = {}

	local function linkParts(part0, part1)
		if
			not part0
			or not part1
			or not part0:IsDescendantOf(model)
			or not part1:IsDescendantOf(model)
		then
			return
		end

		adjacency[part0] = adjacency[part0] or {}
		adjacency[part1] = adjacency[part1] or {}
		adjacency[part0][part1] = true
		adjacency[part1][part0] = true
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("WeldConstraint") then
			linkParts(descendant.Part0, descendant.Part1)
		elseif descendant:IsA("JointInstance") then
			linkParts(descendant.Part0, descendant.Part1)
		end
	end

	local queue = { rootPart }
	connectedLookup[rootPart] = true
	local queueIndex = 1

	while queueIndex <= #queue do
		local current = queue[queueIndex]
		queueIndex += 1

		for connectedPart in pairs(adjacency[current] or {}) do
			if not connectedLookup[connectedPart] then
				connectedLookup[connectedPart] = true
				table.insert(queue, connectedPart)
			end
		end
	end

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart")
			and part ~= rootPart
			and part.Name ~= "PromptRoot"
			and part.Name ~= "SlotPromptRoot"
			and part.Name ~= "BrainrotPromptRoot"
			and part.Name ~= "DropPromptRoot"
		then
			if not connectedLookup[part] then
				local weld = Instance.new("WeldConstraint")
				weld.Name = "GeneratedRootWeld"
				weld.Part0 = rootPart
				weld.Part1 = part
				weld.Parent = rootPart
			end
		end
	end
end

local function CreateGeneratedRootPart(model)
	if not model then
		return nil
	end

	local rootPart = model:FindFirstChild("GeneratedRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		WeldModelToRootPart(model, rootPart)
		model.PrimaryPart = rootPart
		return rootPart
	end

	rootPart = Instance.new("Part")
	rootPart.Name = "GeneratedRootPart"
	rootPart.Size = Vector3.new(1, 1, 1)
	rootPart.Transparency = 1
	rootPart.CastShadow = false
	rootPart.Anchored = false
	rootPart.CanCollide = false
	rootPart.CanTouch = false
	rootPart.CanQuery = false
	rootPart.Massless = true
	rootPart.CFrame = GetModelPivot(model)
	rootPart.Parent = model

	WeldModelToRootPart(model, rootPart)
	model.PrimaryPart = rootPart
	return rootPart
end

local function EnsureModelRootPart(model)
	local rootPart = GetModelRootPart(model)
	if rootPart then
		model.PrimaryPart = rootPart
	else
		rootPart = CreateGeneratedRootPart(model)
	end

	return rootPart
end

local function GetGrabFolder(char)
	local folder = char:FindFirstChild("BrainrotGrab")
	if not folder  then
		folder = Instance.new("Folder")
		folder.Name = "BrainrotGrab"
		folder.Parent = char
	end
	return folder
end

local function GetDroppedFolder()
	local folder = Workspace:FindFirstChild(DROP_FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = DROP_FOLDER_NAME
		folder.Parent = Workspace
	end

	return folder
end

local function ClearDroppedInfo(model)
	local droppedInfo = DroppedBrainrots[model]
	if droppedInfo and droppedInfo.DestroyConn then
		droppedInfo.DestroyConn:Disconnect()
	end

	DroppedBrainrots[model] = nil

	if model then
		model:SetAttribute("Dropped", nil)
		model:SetAttribute("DropPickupOwner", nil)
	end
end

local function StopFloatingModel(model)
	if model and model.Parent then
		GlobalEvent:FireAllClients("StopFlyBrainrot", model)
	end
end

local function StartFloatingModel(model)
	if model and model.Parent then
		GlobalEvent:FireAllClients("FlyBrainrot", model)
	end
end

local function GetDropPromptRarity(model)
	local brainrotInfo = model and BrainrotList[model.Name]
	return brainrotInfo and brainrotInfo.Rarity or nil
end

local function GetDropPromptBonus(model)
	local rarity = GetDropPromptRarity(model)
	local bonus = rarity and dropPromptConfig.RarityBonuses[rarity]
	if not bonus then
		return 0, 0, 0
	end

	return bonus.Height or 0, bonus.ActivationDistance or 0, bonus.ForwardDistance or 0
end

local function GetDropPromptHeight(model)
	local height = dropPromptConfig.BaseHeight
	local hitbox = model and model:FindFirstChild("Hitbox", true)
	if hitbox and hitbox:IsA("BasePart") then
		height += math.clamp(hitbox.Size.Y * dropPromptConfig.HeightHitboxScale, 0, dropPromptConfig.HeightHitboxMax)
	end

	local heightBonus = select(1, GetDropPromptBonus(model))
	height += heightBonus

	return height
end

local function GetDropPromptDistance(model)
	local distance = dropPromptConfig.BaseDistance
	local hitbox = model and model:FindFirstChild("Hitbox", true)
	if hitbox and hitbox:IsA("BasePart") then
		distance += math.clamp(hitbox.Size.Z / 2, 0, dropPromptConfig.DistanceHitboxMax)
	end

	local _, _, distanceBonus = GetDropPromptBonus(model)
	distance += distanceBonus

	return distance
end

local function GetDropPromptActivationDistance(model)
	local _, activationBonus = GetDropPromptBonus(model)
	return dropPromptConfig.BaseActivationDistance + activationBonus
end

local function GetDropPromptRoot(model)
	local rootPart = EnsureModelRootPart(model)
	if not rootPart then
		return nil
	end

	local promptRoot = model:FindFirstChild("DropPromptRoot")
	if promptRoot and not promptRoot:IsA("BasePart") then
		promptRoot:Destroy()
		promptRoot = nil
	end

	if not promptRoot then
		promptRoot = Instance.new("Part")
		promptRoot.Name = "DropPromptRoot"
		promptRoot.Size = Vector3.new(1.2, 1.2, 1.2)
		promptRoot.Transparency = 1
		promptRoot.CastShadow = false
		promptRoot.CanCollide = false
		promptRoot.CanTouch = false
		promptRoot.CanQuery = false
		promptRoot.Massless = true
		promptRoot.Parent = model
	end

	promptRoot.Anchored = false
	local promptOffset = Vector3.new(0, GetDropPromptHeight(model), -GetDropPromptDistance(model))
	promptRoot.CFrame = rootPart.CFrame * CFrame.new(promptOffset)

	local motor = promptRoot:FindFirstChild("DropPromptRootMotor")
	if motor and not motor:IsA("Motor6D") then
		motor:Destroy()
		motor = nil
	end

	if not motor then
		motor = Instance.new("Motor6D")
		motor.Name = "DropPromptRootMotor"
		motor.Parent = promptRoot
	end

	motor.Part0 = rootPart
	motor.Part1 = promptRoot
	motor.C0 = CFrame.new(promptOffset)
	motor.C1 = CFrame.new()

	return promptRoot
end

local function ClearDropPrompt(model)
	local promptRoot = model and model:FindFirstChild("DropPromptRoot")
	if promptRoot and promptRoot:IsA("BasePart") then
		promptRoot:Destroy()
	end
end

local function CreateDropPrompt(model)
	local promptRoot = GetDropPromptRoot(model)
	if not promptRoot then
		return nil
	end

	local attachment = promptRoot:FindFirstChild("DropPromptAttachment")
	if attachment and not attachment:IsA("Attachment") then
		attachment:Destroy()
		attachment = nil
	end

	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "DropPromptAttachment"
		attachment.Parent = promptRoot
	end

	attachment.Position = Vector3.new()

	local prompt = attachment:FindFirstChild(DROP_PROMPT_ACTION)
	if prompt and not prompt:IsA("ProximityPrompt") then
		prompt:Destroy()
		prompt = nil
	end

	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = DROP_PROMPT_ACTION
		prompt.Parent = attachment
	end

	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.ActionText = DROP_PROMPT_ACTION
	prompt.ObjectText = "Brainrot"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 2
	prompt.MaxActivationDistance = GetDropPromptActivationDistance(model)
	prompt.RequiresLineOfSight = false

	return prompt
end

local function ResetStolenSourceModel(model)
	if not model then
		return nil
	end

	local sourceType = model:GetAttribute("StealSourceType") or "Default"
	local sourceMode = model:GetAttribute("StealSourceMode") or ""
	local sourceInPlace = model:GetAttribute("StealSourceInPlace") == true

	model:SetAttribute("InPlace", sourceInPlace)
	model:SetAttribute("Type", sourceType)
	model:SetAttribute("Mode", sourceMode)
	model:SetAttribute("StealSourceType", nil)
	model:SetAttribute("StealSourceMode", nil)
	model:SetAttribute("StealSourceInPlace", nil)

	return { sourceType, sourceMode }
end

local function GetDropPivot(rootPart, model)
	local rootModel = rootPart and rootPart.Parent
	local modelRoot = EnsureModelRootPart(model)
	local forward = rootPart and rootPart.CFrame.LookVector or Vector3.new(0, 0, -1)
	forward = Vector3.new(forward.X, 0, forward.Z)
	if forward.Magnitude < 0.001 then
		forward = Vector3.new(0, 0, -1)
	else
		forward = forward.Unit
	end

	local startPosition = (rootPart and rootPart.Position or GetModelPivot(model).Position) + Vector3.new(0, 4, 0) + (forward * 3)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { model, rootModel }

	local result = Workspace:Raycast(startPosition, Vector3.new(0, -24, 0), rayParams)
	local lift = modelRoot and (modelRoot.Size.Y / 2) or 1
	local targetPosition = result and (result.Position + Vector3.new(0, lift + 0.5, 0)) or startPosition

	return CFrame.lookAt(targetPosition, targetPosition + forward)
end

local function Collisiongroup(model, name)
	if not model then
		return
	end

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			pcall(function()
				part.CollisionGroup = name
			end)
		end
	end
end

function Orientation(Gradient)
	if not Gradient or not Gradient:IsA("UIGradient") then
		return
	end

	if connections[Gradient] then
		connections[Gradient].tween:Cancel()
		connections[Gradient].destroy:Disconnect()
		connections[Gradient] = nil
	end

	Gradient.Rotation = 0

	local tweenInfo = TweenInfo.new(
		2, 
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.InOut,
		-1 
	)

	local tween = TS:Create(Gradient, tweenInfo, {
		Rotation = 360
	})

	local destroyConn = Gradient.Destroying:Connect(function()
		if connections[Gradient] then
			connections[Gradient].tween:Cancel()
			connections[Gradient] = nil
		end
	end)

	tween:Play()

	connections[Gradient] = {
		tween = tween,
		destroy = destroyConn
	}
end

function LabelColor(Label : Instance, name)
	local Gradien = Label:FindFirstChild("Gradien") or Label:FindFirstChildOfClass("UIGradient") or Label:FindFirstChildWhichIsA("UIGradient")
	if not Gradien then Gradien = Instance.new("UIGradient")Gradien.Name = "Gradien" Gradien.Parent = Label end if GuiList.Colors[name] then Gradien.Color = GuiList.Colors[name] Orientation(Gradien) return true end
	return false
end

function BrainrotSelect:BlackList(name)
	local isBlackList = false
	for _, v in pairs(BlackList) do
		if v == name then
			isBlackList = true
			return isBlackList
		end
	end
	return isBlackList
end

function BrainrotSelect:AddWeldToRootPart(Model)
	local rootPart = EnsureModelRootPart(Model)
	if not rootPart then
		return nil
	end

	Model.PrimaryPart = rootPart

	for _, weld in ipairs(rootPart:GetChildren()) do
		if weld:IsA("WeldConstraint") and weld.Name == "MyWeld" then
			weld:Destroy()
		end
	end

	local connectedLookup = {}
	local adjacency = {}

	local function linkParts(part0, part1)
		if
			not part0
			or not part1
			or not part0:IsDescendantOf(Model)
			or not part1:IsDescendantOf(Model)
		then
			return
		end

		adjacency[part0] = adjacency[part0] or {}
		adjacency[part1] = adjacency[part1] or {}
		adjacency[part0][part1] = true
		adjacency[part1][part0] = true
	end

	for _, descendant in ipairs(Model:GetDescendants()) do
		if descendant:IsA("WeldConstraint") then
			linkParts(descendant.Part0, descendant.Part1)
		elseif descendant:IsA("JointInstance") then
			linkParts(descendant.Part0, descendant.Part1)
		end
	end

	local queue = { rootPart }
	connectedLookup[rootPart] = true
	local queueIndex = 1

	while queueIndex <= #queue do
		local current = queue[queueIndex]
		queueIndex += 1

		for connectedPart in pairs(adjacency[current] or {}) do
			if not connectedLookup[connectedPart] then
				connectedLookup[connectedPart] = true
				table.insert(queue, connectedPart)
			end
		end
	end

	for _, part in ipairs(Model:GetDescendants()) do
		if part:IsA("BasePart") and part ~= rootPart then
			part.Anchored = false
			part.Massless = true

			if not connectedLookup[part] then
				local weld = Instance.new("WeldConstraint")
				weld.Name = "MyWeld"
				weld.Part0 = rootPart
				weld.Part1 = part
				weld.Parent = rootPart
			end
		end
	end

	rootPart.Massless = true
	return rootPart
end

function BrainrotSelect:EnsurePrimaryPart(model)
	return EnsureModelRootPart(model)
end

function BrainrotSelect:PreparePlacedModel(model)
	if not model then
		return nil
	end

	local rootPart = EnsureModelRootPart(model)
	if not rootPart then
		return nil
	end

	WeldModelToRootPart(model, rootPart)

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = part == rootPart
			part.Massless = true
			part.CanCollide = false
			part.CanTouch = false
		end
	end

	return rootPart
end

function BrainrotSelect:GetBrainrot(Name, Mutation)
	local NormalFolder = BrainrotModel:WaitForChild("Normal")
	local Folder = nil

	for _, folderName in ipairs(MutationModule:GetLookupNames(Mutation)) do
		Folder = BrainrotModel:FindFirstChild(folderName)
		if Folder then
			break
		end
	end

	Folder = Folder or NormalFolder
	local Model = Folder and Folder:FindFirstChild(Name) or NormalFolder:FindFirstChild(Name)
	if not Model then
		Model = BrainrotModel:FindFirstChild(Name, true)
	end

	Model = Model and Model:Clone()
	if not Model then
		return nil
	end

	self:PreparePlacedModel(Model)
	Collisiongroup(Model, "Brainrot")
	return Model
end

function BrainrotSelect:SetAura(Model, AuraList)
	local VfxInstance = Model:FindFirstChild("VfxInstance")
	local RemoteEvent = require(RP:WaitForChild("MyService"):WaitForChild("Service"):WaitForChild("RemoteEvent"))
	
	if VfxInstance then
		RemoteEvent:FireAllClients("VFXHandler", "Aura", AuraList, Model)
	end
	
end

function BrainrotSelect:ClearProximityPrompt(model)
	for _, v in pairs(model:GetDescendants()) do
		if v:IsA("ProximityPrompt") or (v:IsA("BasePart") and (v.Name == "PromptRoot" or v.Name == "SlotPromptRoot")) then
			v:Destroy()
		end
	end
end

function BrainrotSelect:GetMultiplicater(list)
	local Multiplicater = 0

	for _, v in pairs(list) do
		if MutationModule.Mutation[v] then
			Multiplicater += MutationModule.Mutation[v].Multiplicateur
		end
		if AuraList[v] then
			Multiplicater += AuraList[v].Multiplicateur
		end
	end

	if Multiplicater == 0 then
		return 1
	end

	return Multiplicater
end



function BrainrotSelect:SetInfoByBrairot(model, Mutation, Slots)
	local Multiplicated = {}
	if not Slots then warn(Slots) return end
	
	local list = BrainrotList[model.Name]
	if not list and not model:FindFirstChild("Head") then return end
	
	if not list then
		return
	end
	
	if model:FindFirstChild("Head") and model:FindFirstChild("Head"):FindFirstChild("InfoGui") then
		model:FindFirstChild("Head"):FindFirstChild("InfoGui"):Destroy()
	end
	
	local InfoGui = GuiFolder:WaitForChild("InfoGui"):Clone()
	
	
	InfoGui.Parent = model:FindFirstChild("Head")
	
	
	InfoGui.Rarity.Text = list and list.Rarity
	InfoGui.Title.Text = list and list.DisplayName
	InfoGui.Mutation.Text = Mutation
	InfoGui.Price.Text = TextModule:Suffixe(list.Price).." $"
	
	
	LabelColor(InfoGui.Rarity, list.Rarity)
	LabelColor(InfoGui.Mutation, Mutation)
	
	table.insert(Multiplicated, Mutation)
	
	for index, value in pairs(Slots) do
		local Template = InfoGui.Slot.Template:Clone()
		Template.Name = tostring(index)
		Template.Parent = InfoGui.Slot
		Template.Visible = true
		
		local logoId = AuraList[value] and AuraList[value].ImageId
		
		if logoId then Template.Image = GuiList.Settings.rtbx..logoId end
		table.insert(Multiplicated, value)
		
		
	end
	
	local Multiplicateur = BrainrotSelect:GetMultiplicater(Multiplicated) or 1
	local CashFinal = Round2(list.CashPerSeconde * Multiplicateur)
	InfoGui.CashPerSeconde.Text = TextModule:Suffixe(CashFinal).." $"
	
	model:SetAttribute("CashFinal", CashFinal)
	model:SetAttribute("AuraSlotsJson", HttpService:JSONEncode(Slots))
	BrainrotSelect:SetAura(model, Slots)
	
	task.delay(1, function()
		BrainrotSelect:SetAura(model, Slots)
	end)
	
end

function BrainrotSelect:SetInfoByMode(model, Info, brainrotData)
	local Types = Info[1]
	local Mode = Info[2]
	
	local Position = model:GetAttribute("Position") or model.Parent.Name
	local Head = model:FindFirstChild("Head")

	
	if model then
		if Types == "InMachine" then
			BrainrotSelect:Transparency(model, .6, {"RootPart", "VfxInstance", "Hitbox", "LegsBase"})
			
			if Head:FindFirstChild("InfoGui") then
				Head:FindFirstChild("InfoGui").Enabled = false
			end
			
			if Mode == "InFuse" then
				if not Head:FindFirstChild("Fuse") then
					local FuseGui = RP.Gui.Fuse:Clone()
					FuseGui.Parent = Head
					FuseGui.Title.Text = "InFuse"
					FuseGui.Timer.Text = "00:00:00"
				else
					FuseGui.Title.Text = "InFuse"
					FuseGui.Timer.Text = "00:00:00"
				end
			else
				local FuseGui = Head and Head:FindFirstChild("Fuse")

				if Head:FindFirstChild("InfoGui") then
					Head:FindFirstChild("InfoGui").Enabled = false
				end

				if not FuseGui then
					local FuseGui = RP.Gui.Fuse:Clone()
					FuseGui.Parent = Head
					FuseGui.Timer.Text = ""
					FuseGui.Title.Text = "In Machine"
				else
					FuseGui.Timer.Text = ""
					FuseGui.Title.Text = "In Machine"
				end
			end
			
		elseif Types == "Default" then
			
			for _, v in pairs(Head:GetChildren()) do
				if v:IsA("BillboardGui") then
					v.Enabled = false
				end
			end
			if brainrotData then
				local displayMutation = MutationModule:NormalizeName(
					brainrotData.Mutation or model:GetAttribute("Mutation") or "Normal"
				)
				model:SetAttribute("Mutation", displayMutation)

				if Head:FindFirstChild("InfoGui") then
					Head:FindFirstChild("InfoGui"):Destroy()
				end
				BrainrotSelect:SetInfoByBrairot(model, displayMutation, brainrotData.Slots or {})
			else
				if Head:FindFirstChild("InfoGui") then
					Head:FindFirstChild("InfoGui").Enabled = true
				end
			end
			
			BrainrotSelect:Transparency(model, 0, {"RootPart", "VfxInstance", "Hitbox", "LegsBase"})

		elseif Types == "InPlace" then
			
			BrainrotSelect:InterFaceEnabled(model, "InfoGui", false)
		
		end
	end
	
end

-- =========================
-- Place handlers
-- =========================


function BrainrotSelect:Transparency(model, value)
	if not BrainrotSelect:BlackList(tostring(model:GetAttribute("Mutation"))) then
		local blackList = {"RootPart", "VfxInstance", "Hitbox", "LegsBase", ""}
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				if part.ClassName ~= "Part" then
					local isBlacklisted = false

					for _, name in pairs(blackList or {}) do
						if part.Name == name then
							isBlacklisted = true
							break
						end
					end

					if not isBlacklisted then
						part.Transparency = value or 0
					end
				end
			end
		end
	end
end

function BrainrotSelect:InterFaceEnabled(model, mode, value)
	local Head = model:FindFirstChild("Head")
	if mode == "InfoGui" then
		local InfoGui = Head and Head:FindFirstChild("InfoGui")
		if value then
			for _, v in pairs(InfoGui:GetChildren()) do
				v.Visible = true
			end
		else
			for _, v in pairs(InfoGui:GetChildren()) do
				v.Visible = false
			end
			InfoGui.Title.Visible = true
			InfoGui.Rarity.Visible = true
		end
	end
end

function BrainrotSelect:Place(char, model, brainrotData, attribute)
	if not char or char:GetAttribute("Grab") or self:GetGrabModel(char) then
		return false
	end

	if PlaceBrainrot[char] then self:RemovePlace(char) end
	
	local NewModel = model:Clone()
	self:GrabModel(char, NewModel)
	char:SetAttribute("InPlace", true)
	
	self:ClearProximityPrompt(NewModel)
	
	
	self:Transparency(model, .6, {"RootPart", "VfxInstance", "Hitbox", "LegsBase"})
	model:SetAttribute("InPlace", true)
	
	model:SetAttribute("Type", "InPlace")
	
	if brainrotData then
		self:SetInfo(char, brainrotData.Name, brainrotData.Mutation, brainrotData.Slots)
	end
	
	PlaceBrainrot[char] = model
	return true
end

function BrainrotSelect:GetPlace(char)
	return PlaceBrainrot[char]
end

function BrainrotSelect:RemovePlace(char)
	PlaceBrainrot[char] = nil
end

-- =========================
-- Grab handlers
-- =========================

function BrainrotSelect:DisableCollision(model)
	if not model then return end

	self:PreparePlacedModel(model)

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanTouch = false
			part.CanCollide = false
		end
	end
end

function BrainrotSelect:PrepareDroppedModel(model)
	local rootPart = EnsureModelRootPart(model)
	if not model or not rootPart then
		return nil
	end

	self:ClearProximityPrompt(model)
	ClearDropPrompt(model)

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.Massless = true
			part.CanTouch = false
			part.CanQuery = true
			part.CanCollide = false
		end
	end

	return rootPart
end

function BrainrotSelect:GetGrabModel(char)
	local GrabFolder = GetGrabFolder(char)
	if # GrabFolder:GetChildren() == 1 then
		for _, model in ipairs(GrabFolder:GetChildren()) do
			return model
		end
	end
end

function BrainrotSelect:GrabModel(char, model)
	local GrabFolder = GetGrabFolder(char)

	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local distance = 4
	local hitbox = model:FindFirstChild("Hitbox", true)
	if hitbox and hitbox:IsA("BasePart") then
		distance = distance + (hitbox.Size.Z / 2) + 1.5
	end

	local modelRoot = EnsureModelRootPart(model)
	if not modelRoot then
		warn("GrabModel: Aucun PrimaryPart trouve")
		return
	end

	char:SetAttribute("Grab", true)

	model.Parent = GrabFolder
	self:DisableCollision(model)
	self:AddWeldToRootPart(model)
	model:PivotTo(root.CFrame * CFrame.new(0, 1.5, -distance))

	local weld = Instance.new("WeldConstraint")
	weld.Name = "GrabWeld"
	weld.Part0 = root
	weld.Part1 = model.PrimaryPart
	weld.Parent = model.PrimaryPart

	model:SetAttribute("Grabbed", true)
	model:SetAttribute("GrabOwner", char.Name)
end

function BrainrotSelect:ClearGrab(char)
	task.spawn(function()
		local GrabFolder = GetGrabFolder(char)
		repeat
			GrabFolder:ClearAllChildren()
			task.wait()
		until #GrabFolder:GetChildren() == 0
	end)
end

function BrainrotSelect:UnGrab(char, value)
	local GrabFolder : Folder = GetGrabFolder(char)
	local model = GrabFolder:FindFirstChildOfClass("Model") or GrabFolder:FindFirstChildWhichIsA("Model")
	
	if not model then return end

	local weld = model.PrimaryPart and model.PrimaryPart:FindFirstChild("GrabWeld")
	if weld then
		weld:Destroy()
	end

	model:SetAttribute("Grabbed", nil)
	model:SetAttribute("GrabOwner", nil)
	char:SetAttribute("Grab", false)

	if value then
		return model
	else
		model:Destroy()
	end
	
	return nil
end

function BrainrotSelect:GetDroppedInfo(model)
	return DroppedBrainrots[model]
end

function BrainrotSelect:ReleaseOwnerReferences(ownerName)
	local releasedSources = {}

	if not ownerName or ownerName == "" then
		return releasedSources
	end

	for char, placeModel in pairs(PlaceBrainrot) do
		if placeModel and placeModel:GetAttribute("Owner") == ownerName then
			local carryType = char:GetAttribute("Type")

			if carryType == "Steal" then
				releasedSources[placeModel] = true
				local grabbedModel = self:GetGrabModel(char)
				if grabbedModel then
					grabbedModel:SetAttribute("Owner", nil)
				end

				PlaceBrainrot[char] = nil
				char:SetAttribute("InPlace", false)
				char:SetAttribute("Type", "Buy")
			elseif carryType == "InPlace" then
				PlaceBrainrot[char] = nil
			end
		end
	end

	for droppedModel, droppedInfo in pairs(DroppedBrainrots) do
		local placeModel = droppedInfo and droppedInfo.PlaceModel
		if placeModel and placeModel:GetAttribute("Owner") == ownerName then
			releasedSources[placeModel] = true
			droppedInfo.Type = "Buy"
			droppedInfo.InPlace = false
			droppedInfo.PlaceModel = nil

			if droppedModel then
				droppedModel:SetAttribute("Owner", nil)
				droppedModel:SetAttribute("DropPickupOwner", nil)
			end
		end
	end

	return releasedSources
end

function BrainrotSelect:DropCarry(char)
	if not char then
		return nil
	end

	local carryType = char:GetAttribute("Type")
	if carryType ~= "Buy" and carryType ~= "Steal" and carryType ~= "InPlace" then
		return nil
	end

	local carryInfo = self:GetInfo(char)
	if not carryInfo then
		return nil
	end

	local placeModel = self:GetPlace(char)
	local rootPart = char:FindFirstChild("HumanoidRootPart")
	local droppedModel = self:UnGrab(char, true)

	if not droppedModel then
		return nil
	end

	ClearDroppedInfo(droppedModel)

	droppedModel.Parent = GetDroppedFolder()
	self:PrepareDroppedModel(droppedModel)
	droppedModel:PivotTo(GetDropPivot(rootPart, droppedModel))
	droppedModel:SetAttribute("Dropped", true)
	droppedModel:SetAttribute("DropPickupOwner", nil)

	if carryType == "InPlace" and placeModel then
		placeModel:SetAttribute("Mode", "DroppedCarry")
	end

	CreateDropPrompt(droppedModel)
	StartFloatingModel(droppedModel)

	DroppedBrainrots[droppedModel] = {
		Type = carryType,
		InPlace = char:GetAttribute("InPlace") == true,
		Info = {
			Name = carryInfo.Name,
			Mutation = carryInfo.Mutation,
			Slots = CloneTable(carryInfo.Slots),
		},
		PlaceModel = placeModel,
	}

	DroppedBrainrots[droppedModel].DestroyConn = droppedModel.Destroying:Connect(function()
		StopFloatingModel(droppedModel)
		ClearDroppedInfo(droppedModel)
	end)

	self:RemoveInfo(char)
	self:RemovePlace(char)
	char:SetAttribute("InPlace", false)
	char:SetAttribute("Type", "None")

	return droppedModel
end

function BrainrotSelect:PickupDropped(char, model)
	if not char or not model then
		return false
	end

	if not char:FindFirstChild("HumanoidRootPart") then
		return false
	end

	local droppedInfo = DroppedBrainrots[model]
	if not droppedInfo or not droppedInfo.Info then
		return false
	end

	if char:GetAttribute("Grab") or self:GetGrabModel(char) then
		return false
	end

	local pickupModel = self:GetBrainrot(droppedInfo.Info.Name, droppedInfo.Info.Mutation)
	if not pickupModel then
		return false
	end

	pickupModel:SetAttribute("Owner", model:GetAttribute("Owner"))
	pickupModel:SetAttribute("Mutation", droppedInfo.Info.Mutation or "Normal")
	self:SetInfoByBrairot(
		pickupModel,
		droppedInfo.Info.Mutation or "Normal",
		CloneTable(droppedInfo.Info.Slots)
	)

	ClearDroppedInfo(model)
	ClearDropPrompt(model)
	StopFloatingModel(model)
	model:Destroy()

	local pickupType = droppedInfo.Type or "None"
	if droppedInfo.Type == "InPlace" and droppedInfo.PlaceModel then
		local sourceOwner = droppedInfo.PlaceModel:GetAttribute("Owner")
		if sourceOwner and sourceOwner ~= char.Name then
			pickupType = "Steal"
			droppedInfo.PlaceModel:SetAttribute("StealSourceType", "Default")
			droppedInfo.PlaceModel:SetAttribute("StealSourceMode", "")
			droppedInfo.PlaceModel:SetAttribute("StealSourceInPlace", false)
			droppedInfo.PlaceModel:SetAttribute("Mode", "InSteal")
		else
			pickupType = "InPlace"
			droppedInfo.PlaceModel:SetAttribute("Mode", "")
		end
	elseif droppedInfo.Type == "InPlace" then
		pickupType = "Buy"
	end

	self:GrabModel(char, pickupModel)
	self:SetInfo(char, droppedInfo.Info.Name, droppedInfo.Info.Mutation, CloneTable(droppedInfo.Info.Slots))

	PlaceBrainrot[char] = droppedInfo.PlaceModel

	char:SetAttribute("InPlace", pickupType ~= "Buy" and droppedInfo.InPlace == true)
	char:SetAttribute("Type", pickupType)

	return true
end

function BrainrotSelect:CreateAbandonedDrop(model, brainrotData)
	if not (model and brainrotData) then
		return nil
	end

	ClearDroppedInfo(model)
	ClearDropPrompt(model)
	StopFloatingModel(model)

	model.Parent = GetDroppedFolder()
	self:PrepareDroppedModel(model)
	model:SetAttribute("Owner", nil)
	model:SetAttribute("Position", nil)
	model:SetAttribute("Mutation", brainrotData.Mutation or model:GetAttribute("Mutation") or "Normal")
	model:SetAttribute("Type", "Default")
	model:SetAttribute("Mode", "")
	model:SetAttribute("InPlace", false)
	model:SetAttribute("Dropped", true)
	model:SetAttribute("DropPickupOwner", nil)

	self:SetInfoByMode(model, { "Default", "" }, brainrotData)
	CreateDropPrompt(model)
	StartFloatingModel(model)

	DroppedBrainrots[model] = {
		Type = "Buy",
		InPlace = false,
		Info = {
			Name = brainrotData.Name,
			Mutation = brainrotData.Mutation,
			Slots = CloneTable(brainrotData.Slots),
		},
		PlaceModel = nil,
	}

	DroppedBrainrots[model].DestroyConn = model.Destroying:Connect(function()
		StopFloatingModel(model)
		ClearDroppedInfo(model)
	end)

	return model
end

function BrainrotSelect:RestoreSteal(char)
	if not char then
		return false
	end

	local placeModel = self:GetPlace(char)
	if not placeModel then
		return false
	end

	local grabbedModel = self:UnGrab(char, true)
	if grabbedModel then
		StopFloatingModel(grabbedModel)
		grabbedModel:Destroy()
	end

	local restoreInfo = ResetStolenSourceModel(placeModel)
	if restoreInfo then
		self:SetInfoByMode(placeModel, restoreInfo)
	end

	self:ClearGrab(char)
	self:RemoveInfo(char)
	self:RemovePlace(char)
	char:SetAttribute("Grab", false)
	char:SetAttribute("InPlace", false)
	char:SetAttribute("Type", "None")

	return true
end

-- =========================
-- Brainrot Info handlers
-- =========================

function BrainrotSelect:GetSlotsTable(count)
	local Table = {}

	for i = 1, count do
		Table[tostring(i)] = ""
	end
	return Table
end

function BrainrotSelect:SetInfo(char, ...)
	if not char then warn("char == nil !") return end
	local Halls = {...}
	
	local TableRecup = {
		Name = Halls[1],
		Mutation = Halls[2],
		Slots = Halls[3]
	}
	
	if not BrainrotInfo[char] then
		BrainrotInfo[char] = {}
	end
	
	BrainrotInfo[char] = TableRecup
	return BrainrotInfo[char], BrainrotInfo
end

function BrainrotSelect:GetInfo(char)
	return BrainrotInfo[char]
end


function BrainrotSelect:RemoveInfo(char)
	BrainrotInfo[char] = nil
end

return BrainrotSelect
