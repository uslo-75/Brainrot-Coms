local ProximityPromptService = game:GetService("ProximityPromptService")
local RP = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local myServices = require(RP:WaitForChild("MyService"):WaitForChild("MyService"))


local BrainrotSelect = require(game.ServerStorage.Module.BrainrotSelect)
local DataManager = require(game.ServerStorage.Data.DataManager)
local BaseModule = require(game.ServerStorage.Module.GameHandler.Base)
local BrainrotDisplayName = require(RP:WaitForChild("Module"):WaitForChild("BrainrotDisplayName"))
local BrainrotList = require(game.ServerStorage.List.BrainrotList)
local MessageModule = require(game.ReplicatedStorage.Module.MessageModule)

local ProximityPrompt = {}
local ServiceTable = {}
local Triggered = {}
local DB = {}
local StealInfo = {}
ProximityPrompt.Initialized = false

local function GetBrainrotDisplayName(name)
	local brainrotData = BrainrotList[name]
	return BrainrotDisplayName.Get(name, brainrotData)
end

local function CreateAttache(parent, name, pos)
	local attache = Instance.new("Attachment")
	attache.Parent = parent
	attache.Name = name
	attache.Position = pos or Vector3.new(0,0,0)
	return attache
end

local function GetSlotBrainrotModel(slotModel)
	if not slotModel then
		return nil
	end

	for _, child in ipairs(slotModel:GetChildren()) do
		if child:IsA("Model")
			and child.Name ~= "PromptRoot"
			and child.Name ~= "SlotPromptRoot"
			and child.Name ~= "BrainrotPromptRoot"
			and (child:GetAttribute("Type") ~= nil or child:GetAttribute("Position") ~= nil)
		then
			return child
		end
	end

	return nil
end

local function IsMachineState(model)
	if not model then
		return false
	end

	local mode = model:GetAttribute("Mode")
	return model:GetAttribute("Type") == "InMachine"
		or mode == "AuraSpin"
		or mode == "Fusion"
		or mode == "InFuse"
		or mode == "Fusing"
end

local function IsAuraMachineState(model)
	return model and model:GetAttribute("Mode") == "AuraSpin"
end

local function GetPromptModel(prompt)
	local current = prompt and prompt.Parent
	local fallbackModel = nil
	local slotModel = nil
	local brainrotModel = nil
	local actionText = prompt and prompt.ActionText

	while current do
		if current:IsA("Model") then
			fallbackModel = fallbackModel or current

			if current:GetAttribute("Type") ~= nil then
				brainrotModel = current
			elseif current:GetAttribute("Enter") ~= nil then
				slotModel = current
			end
		end

		current = current.Parent
	end

	if actionText == "Place Brainrot" then
		return slotModel or brainrotModel or fallbackModel
	end

	if brainrotModel then
		return brainrotModel
	end

	if slotModel and slotModel:GetAttribute("Enter") then
		return GetSlotBrainrotModel(slotModel) or slotModel
	end

	return fallbackModel
end


local function AddToTriggered(arg1, arg2)
	if not Triggered[arg1] then
		Triggered[arg1] = arg2
	end
end

local function RemoveFromTriggered(arg1)
	if Triggered[arg1] then
		Triggered[arg1] = nil
	end
end

local function GetTriggered(arg1)
	return Triggered[arg1]
end

local function CanPlayerInteractWithPrompts(player)
	if not player then
		return false
	end

	local char = player.Character
	if not (char and char.Parent) then
		return false
	end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil
		and humanoid.Health > 0
		and humanoid:GetState() ~= Enum.HumanoidStateType.Dead
end

local function Transparency(model, value, blackList)
	value = value or 0
	blackList = blackList or {}

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local isBlacklisted = false
			for _, name in ipairs(blackList) do
				if part.Name == name then
					isBlacklisted = true
					break
				end
			end


			if not isBlacklisted  and part.Transparency ~= 1 then
				part.Transparency = value
			end
		end
	end
end

local function RemoveProximity(model)
	for _, prompt in ipairs(model:GetDescendants()) do
		if prompt:IsA("ProximityPrompt") then
			prompt:Destroy()
		end
	end
end

local function Anchored(model, value)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = value
		end
	end
end


local function SetTriggered(prompt : ProximityPrompt, player : Player)
	if not CanPlayerInteractWithPrompts(player) then
		return
	end

	local result = string.gsub(prompt.ActionText, "%s+", "")

	if ProximityPrompt[result] then
		ProximityPrompt[result](ProximityPrompt, prompt, player)
	end

end

function ProximityPrompt:createPrompt(actionText, parent, duration)
	local prompt = parent:FindFirstChild(actionText)
	if prompt and not prompt:IsA("ProximityPrompt") then
		prompt:Destroy()
		prompt = nil
	end

	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = actionText
		prompt.Parent = parent
	end

	prompt.ActionText = actionText
	prompt.ObjectText = "Brainrot"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = duration
	prompt:SetAttribute("ForceNoLineOfSight", true)
	prompt.RequiresLineOfSight = false
	return prompt
end

local function ResetBaseBrainrotState(model)
	if not model then
		return
	end

	model:SetAttribute("Type", "Default")
	model:SetAttribute("Mode", "")
	model:SetAttribute("InPlace", false)
end

local function ResetBaseBrainrotByPosition(player, position)
	local base = BaseModule.GetBase(player)
	local model = base and base:GetModelBySlots(tostring(position))

	ResetBaseBrainrotState(model)
	return model
end

local function ClearCarryState(char)
	if not char then
		return
	end

	BrainrotSelect:UnGrab(char)
	BrainrotSelect:ClearGrab(char)
	BrainrotSelect:RemovePlace(char)
	BrainrotSelect:RemoveInfo(char)

	char:SetAttribute("InPlace", false)
	char:SetAttribute("Type", "None")
end

local function CleanupStolenSource(char, brainrotInfo)
	local sourceModel = BrainrotSelect:GetPlace(char)
	if not sourceModel then
		return false
	end

	local owner = sourceModel:GetAttribute("Owner")
	local playerFound = owner and Players:FindFirstChild(owner)
	local sourceMode = sourceModel:GetAttribute("StealSourceMode") or sourceModel:GetAttribute("Mode") or ""

	if sourceModel.Parent then
		sourceModel.Parent:SetAttribute("Enter", false)
	end

	if playerFound then
		DataManager.RemoveBrainrot(playerFound, sourceModel:GetAttribute("Position"))
		MessageModule:SendMessage(
			playerFound,
			`{char.Name} has stolen your brainrot {GetBrainrotDisplayName(brainrotInfo.Name)}`,
			3.5
		)

		if sourceMode == "AuraSpin" then
			DataManager:ClearAuraSpin(playerFound)
		end
	end

	sourceModel:Destroy()
	return true
end

local function ChangePosition(player, CurrentPosition, NewPosition)
	local NewBase = BaseModule.GetBase(player)

	local function UpdateBrairot(BrairotInfo)
		NewBase.UpdateBrairot:Fire(BrairotInfo.Name,
			BrairotInfo.Mutation,
			BrairotInfo.Position,
			BrairotInfo.Slots,
			0
		)
	end


	if NewBase and NewBase.StockBrainrot then
		local CurrentSpots : Model, NewSpots : Model = NewBase.StockBrainrot:FindFirstChild(CurrentPosition), NewBase.StockBrainrot:FindFirstChild(NewPosition)
		if CurrentSpots and NewSpots then
			local M1 = CurrentSpots:FindFirstChildWhichIsA("Model") or CurrentSpots:FindFirstChildOfClass("Model")
			local M2 = NewSpots:FindFirstChildWhichIsA("Model") or NewSpots:FindFirstChildOfClass("Model")
			if M1 then M1:Destroy() end
			if M2 then M2:Destroy() end

			CurrentSpots:SetAttribute("Enter", false)
			NewSpots:SetAttribute("Enter", false)

			local info1, info2 = DataManager:ChangePosition(player, CurrentPosition, NewPosition)
			if info1 and info2 then
				UpdateBrairot(info1)
				UpdateBrairot(info2)
				ResetBaseBrainrotByPosition(player, info1.Position)
				ResetBaseBrainrotByPosition(player, info2.Position)
			end

		end
	end
end

function ProximityPrompt:AuraAsset(model)
	local playerOwner = Players:FindFirstChild(model:GetAttribute("Owner"))

	if playerOwner then

	end
end

function ProximityPrompt:Place(prompt : ProximityPrompt, player : Player)	

	if not DB[player] then
		DB[player] = true
		task.delay(.1, function() DB[player] = nil end)
		local char = player.Character or player.CharacterAdded:Wait()
		local model = GetPromptModel(prompt)

		if not model then
			return
		end

		if model:GetAttribute("Mode") == "InSteal" or model:GetAttribute("Mode") == "DroppedCarry" then
			return
		end

		if model and model:GetAttribute("Owner") == player.Name and IsMachineState(model) then
			if IsAuraMachineState(model) then
				self:Return(prompt, player)
			end
			return
		end

		if not char:GetAttribute("InPlace") then
			if char:GetAttribute("Grab") or BrainrotSelect:GetGrabModel(char) then
				return
			end


			if model and model:GetAttribute("Owner") == player.Name and model:GetAttribute("Mode") ~= "Fusing" then
				local BrainrotData = DataManager.GetBrainrot(player, model:GetAttribute("Position"))
				if not char:GetAttribute("InPlace") and BrainrotData then
					if BrainrotSelect:Place(char, model, BrainrotData) then
						char:SetAttribute("Type", "InPlace")
					end
				end
			end
		else

			local BrairotInfo = DataManager.GetBrainrot(player, model:GetAttribute("Position") or 0)
			local BrairotGrab = BrainrotSelect:GetGrabModel(char)

			if BrairotInfo and BrairotGrab then
				local NewPosition = model:GetAttribute("Position")
				if BrairotGrab:GetAttribute("Position") == NewPosition  then
					ResetBaseBrainrotState(model)
				else
					local currentPosition = BrairotGrab:GetAttribute("Position")

					ChangePosition(player, currentPosition, NewPosition)

				end

				BrainrotSelect:UnGrab(char)
				BrainrotSelect:ClearGrab(char)
				BrainrotSelect:RemovePlace(char)
				BrainrotSelect:RemoveInfo(char)

				char:SetAttribute("InPlace", false)
				char:SetAttribute("Type", "None")
			end
		end
	end

end

function ProximityPrompt:PlaceBrainrot(prompt : ProximityPrompt, player : Player)
	local char = player.Character or player.CharacterAdded:Wait()
	local model = GetPromptModel(prompt)

	if not model then
		return
	end

	if model:GetAttribute("Owner") == player.Name and IsMachineState(model) then
		if IsAuraMachineState(model) then
			self:Return(prompt, player)
		end
		return
	end

	if model:GetAttribute("Owner") ~= player.Name then
		return
	end

	if char:GetAttribute("InPlace") and not model:GetAttribute("Enter") then
		local BrairotGrab = BrainrotSelect:GetGrabModel(char)
		if not BrairotGrab then
			return
		end

		local CurrentPosition = BrairotGrab:GetAttribute("Position")
		local NewPosition = model.Name
		local BrainrotData = BrainrotSelect:GetInfo(char)
		local BrainrotPlace = BrainrotSelect:GetPlace(char)
		local carryType = char:GetAttribute("Type")
		local didPlace = false

		if CurrentPosition ~= NewPosition and BrainrotData then
			if carryType == "Steal" then
				didPlace = CleanupStolenSource(char, BrainrotData)
			elseif BrainrotPlace and DataManager.GetBrainrot(player, CurrentPosition) then
				DataManager.RemoveBrainrot(player, CurrentPosition)

				if BrainrotPlace.Parent then
					BrainrotPlace.Parent:SetAttribute("Enter", false)
				end

				BrainrotPlace:Destroy()
				didPlace = true
			end

			if didPlace then
				local newBrainrot = DataManager.AddBrainrot(
					player,
					BrainrotData.Name,
					BrainrotData.Mutation,
					BrainrotData.Slots,
					NewPosition,
					0
				)

				local NewBase = newBrainrot and BaseModule.GetBase(player)

				if NewBase then
					NewBase.UpdateBrairot:Fire(
						BrainrotData.Name,
						BrainrotData.Mutation,
						NewPosition,
						BrainrotData.Slots,
						0
					)
					ResetBaseBrainrotByPosition(player, NewPosition)
				end

				if carryType == "Steal" and newBrainrot then
					DataManager.AddCurrency("Steal", 1, player)
					DataManager.AddIndex(player, BrainrotData.Name, BrainrotData.Mutation)
				end
			end
		end

		if didPlace then
			ClearCarryState(char)
		end

	end
end

local function CashLabelApply(part, text)
	if part and text then
		local CashLabel = part:FindFirstChild("CashLabel")
		if not CashLabel then
			CashLabel = RP.Gui.CashLabel:Clone()
			CashLabel.Parent = part
		end
		CashLabel.Label.Text = text
	end
end

function ProximityPrompt:StealAsset(char)

end

local function Delete(player, model, SlotModel)
	if IsMachineState(model) then
		return false
	end

	if not SlotModel or SlotModel.ClassName ~= "Model" then
		SlotModel = model.Parent
	end

	local succes = DataManager.RemoveBrainrot(player, SlotModel.Name)

	if succes and model then
		model:Destroy()

		if SlotModel:FindFirstChild("ClaimCash") then
			CashLabelApply(SlotModel:FindFirstChild("ClaimCash"), "")
		end

		SlotModel:SetAttribute("Enter", false)
		SlotModel:SetAttribute("CashPerSeconde", nil)
	else
		warn("Pas de succes !!")
	end

end

function ProximityPrompt:Delete(prompt : ProximityPrompt, player : Player)
	local char = player.Character or player.CharacterAdded:Wait()
	local model = GetPromptModel(prompt)
	if model and not char:GetAttribute("InPlace") then
		if char:GetAttribute("Grab") or BrainrotSelect:GetGrabModel(char) then
			return
		end

		if model:GetAttribute("Mode") == "InSteal" or model:GetAttribute("Mode") == "DroppedCarry" or IsMachineState(model) then
			return
		end

		local owner = model:GetAttribute("Owner")
		if owner == player.Name then
			Delete(player, model, model.Parent)
		end

	end
end

function ProximityPrompt:Steal(prompt : ProximityPrompt, player : Player)
	if not DB[player] then
		DB[player] = true
		local char = player.Character or player.CharacterAdded:Wait()
		local model = GetPromptModel(prompt)
		task.delay(.15, function() DB[player] = nil end)
		if model and not char:GetAttribute("InPlace") then
			if char:GetAttribute("Grab") or BrainrotSelect:GetGrabModel(char) then
				return
			end

			if model:GetAttribute("Mode") == "InSteal" or model:GetAttribute("Mode") == "DroppedCarry" or model:GetAttribute("InPlace") then
				return
			end

			local owner = model:GetAttribute("Owner")
			if owner == player.Name then return end
			local playerFound = Players:FindFirstChild(owner)
			if playerFound then

				MessageModule:SendMessage(playerFound, `Someone is stealing your brainrot {GetBrainrotDisplayName(model.Name)}`, 1.5)

				local BrainrotData = DataManager.GetBrainrot(playerFound, model:GetAttribute("Position"))
				if not char:GetAttribute("InPlace") and BrainrotData then
					StealInfo[char] = BrainrotData
					model:SetAttribute("StealSourceType", model:GetAttribute("Type") or "Default")
					model:SetAttribute("StealSourceMode", model:GetAttribute("Mode") or "")
					model:SetAttribute("StealSourceInPlace", model:GetAttribute("InPlace") == true)
					model:SetAttribute("Mode", "InSteal")
					if BrainrotSelect:Place(char, model, BrainrotData) then
						char:SetAttribute("Type", "Steal")
					end
				end
			end
		end
	end
end

function ProximityPrompt:PickUp(prompt : ProximityPrompt, player : Player)
	if DB[player] then
		return
	end

	DB[player] = true
	task.delay(.15, function()
		DB[player] = nil
	end)

	local char = player.Character or player.CharacterAdded:Wait()
	if char:GetAttribute("Grab") or char:GetAttribute("InPlace") then
		return
	end

	local model = GetPromptModel(prompt)
	if model then
		BrainrotSelect:PickupDropped(char, model)
	end
end

local function GetPrompt(model : Model, name)
	for _, prompt in pairs(model:GetDescendants()) do
		if prompt:IsA("ProximityPrompt") then
			if prompt.Name == name then
				return prompt
			end
		end
	end
end

function ProximityPrompt:Return(prompt : ProximityPrompt, player : Player)
	local model = GetPromptModel(prompt)
	local brainrotData = nil

	if not model then
		return
	end

	if model:GetAttribute("Owner") == player.Name and IsMachineState(model) then
		if not IsAuraMachineState(model) then
			return
		end

		if IsMachineState(model) then
			local profile = DataManager:GetProfile(player)
			local data = profile and profile.Data
			local Place = GetPrompt(model, "Place")
			local Delete = GetPrompt(model, "Delete")
			local position = model:GetAttribute("Position")
			local mode = model:GetAttribute("Mode")
			brainrotData = position and DataManager.GetBrainrot(player, position)

			if data then
				if mode == "AuraSpin" then
					DataManager:ClearAuraSpin(player)
				end
				for index, value in pairs(data.Fuse.Fusing) do
					if value.Name == model.Name and value.Position == model:GetAttribute("Position") then
						table.remove(data.Fuse.Fusing, index)
					end
				end



			end


		end

		model:SetAttribute("InPlace", false)
		model:SetAttribute("Type", "Default")
		model:SetAttribute("Mode", "")
		BrainrotSelect:SetInfoByMode(model, {"Default", ""}, brainrotData)
	end

end

function ProximityPrompt:Init(DataManager)
	if self.Initialized then
		return true
	end

	self.Initialized = true
	ProximityPromptService.PromptTriggered:Connect(SetTriggered)
	ServiceTable["RemoteEvent"] = myServices:LoadService("RemoteEvent") or myServices:GetService("RemoteEvent")

	ServiceTable["DataManager"] = DataManager
end


return ProximityPrompt
