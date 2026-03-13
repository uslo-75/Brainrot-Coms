--//[Services]//--

local Players = game:GetService("Players")
local RP = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

--//[Folder]//--

local Map = Workspace:WaitForChild("Map")

--//[Events]//--

local ProximityPromptEvent = RP:WaitForChild("Events"):WaitForChild("RemoteEvents"):WaitForChild("ProximityPromptEvent")

--//[Modules]//--

local Signal = require(RP.Module.Signal)
local BrainrotSelect = require(ServerStorage.Module.BrainrotSelect)
local UpgradeList = require(ServerStorage.List.UpgradeList)
local GameConfig = require(RP:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local MessageModule = require(RP:WaitForChild("Module"):WaitForChild("MessageModule"))
local AddCash = ServerStorage.AddCash
local GlobalEvent = RP.Events.RemoteEvents.GlobaleEvent

local Base = {}

local Hits = {}
local ServiceTable = {}
local I = {}
Base.__index = Base
local slotPromptConfig = GameConfig.Prompts.BaseSlot

local SLOT_PROMPT_VERTICAL_OFFSET = slotPromptConfig.VerticalOffset
local SLOT_PROMPT_FORWARD_OFFSET = slotPromptConfig.ForwardOffset
local SLOT_PROMPT_MAX_ACTIVATION_DISTANCE = slotPromptConfig.MaxActivationDistance

------------------------------
-----//Prompt Fonction Brainrot //-----
------------------------------

local function CreateAttache(parent, name, pos)
	local attache = parent:FindFirstChild(name)
	if attache and not attache:IsA("Attachment") then
		attache:Destroy()
		attache = nil
	end

	if not attache then
		attache = Instance.new("Attachment")
		attache.Name = name
		attache.Parent = parent
	end

	attache.Position = pos or Vector3.new(0, 0, 0)
	return attache
end

local function CreatePromptRoot(container, name, targetPart, worldCFrame)
	if not container or not targetPart then
		return nil
	end

	local promptRoot = container:FindFirstChild(name)
	if promptRoot and not promptRoot:IsA("BasePart") then
		promptRoot:Destroy()
		promptRoot = nil
	end

	if not promptRoot then
		promptRoot = Instance.new("Part")
		promptRoot.Name = name
		promptRoot.Size = Vector3.new(1, 1, 1)
		promptRoot.Transparency = 1
		promptRoot.CastShadow = false
		promptRoot.Parent = container
	end

	promptRoot.Anchored = false
	promptRoot.CanCollide = false
	promptRoot.CanTouch = false
	promptRoot.CanQuery = false
	promptRoot.Massless = true
	promptRoot.CFrame = worldCFrame

	local weld = promptRoot:FindFirstChild("PromptRootWeld")
	if weld and not weld:IsA("WeldConstraint") then
		weld:Destroy()
		weld = nil
	end

	if not weld then
		weld = Instance.new("WeldConstraint")
		weld.Name = "PromptRootWeld"
		weld.Parent = promptRoot
	end

	weld.Part0 = promptRoot
	weld.Part1 = targetPart

	return promptRoot
end

local function DestroyPromptRoot(container, name)
	if not container then
		return
	end

	local promptRoot = container:FindFirstChild(name)
	if promptRoot then
		promptRoot:Destroy()
	end
end

local function GetSlotPromptCFrame(targetPart, verticalOffset, forwardOffset)
	if not targetPart then
		return nil
	end

	return targetPart.CFrame
		* CFrame.new(0, verticalOffset or SLOT_PROMPT_VERTICAL_OFFSET, forwardOffset or SLOT_PROMPT_FORWARD_OFFSET)
end

local function createPrompt(actionText, parent, duration)
	if not parent then
		return nil
	end

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
	prompt.MaxActivationDistance = SLOT_PROMPT_MAX_ACTIVATION_DISTANCE
	prompt.RequiresLineOfSight = false
	return prompt
end

------------------------------
-----//Create Base //-----
------------------------------

function Base.new(player, data, DataManager)
	local self = setmetatable({}, Base)
	local Rebirth = player:WaitForChild("leaderstats"):WaitForChild("Rebirth")

	self.UpdateBrairot = Instance.new("BindableEvent")
	self.CashUpdate = Signal.new()
	self.UpgradeBase = Signal.new()
	self.BaseLevel = Rebirth and Rebirth.Value or 0
	self.Multiplicateur = 1
	self.StockBrainrot = nil
	self.Model = nil
	self.LockPartFolder = nil
	self.Owner = player.Name
	self.player = player
	self.Lookced = true
	self.TimeLock = 240
	self.Data = data and data.Data

	ServiceTable["DataManager"] = DataManager

	self:ApplyInfoByRebrith()
	self:SetModel()
	self:Init()
	self:MoveChar()

	I[player] = self

	return self
end

function Base:GetMultiplicated()
	local player = self.player
	local CashBuff = player and player:FindFirstChild("Stats") and player.Stats:FindFirstChild("CashBuff")
	local finalCash = 0
	if self then
		finalCash = self.Multiplicateur or 1
	end
	if CashBuff then
		finalCash += CashBuff.Value
	end

	if finalCash < 1 then
		finalCash += 1
	end
	return finalCash
end

function Base:ApplyInfoByRebrith()
	if self.player then
		local Rebirth = self.player:WaitForChild("leaderstats"):WaitForChild("Rebirth")
		local Info = UpgradeList[tostring(Rebirth.Value)]
		if Info then
			self.Multiplicateur = Info.Reward.Multiplicateur
			self.TimeLock = Info.Reward.TimeLock
		end
	end

	if self.Model then
		self.Model:SetAttribute("Multiplicateur", self.Multiplicateur)
	end
end

function Base:MoveChar()
	local character = self.player.Character
	if not character then
		return
	end

	if self.Model then
		character:MoveTo(self.Model.MoveChar.Position)
	end
end

function Base:GetMode(position)
	if self.Data then
		local AuraSpinData = self.Data.AuraSpin

		if position == AuraSpinData.Position then
			return "InMachine", "AuraSpin"
		end

		if self.Data.Fuse then
			for _, brairot in pairs(self.Data.Fuse.Fusing) do
				if brairot.Position == position then
					if self.Data.Fuse.FuseMode ~= "None" then
						return "InMachine", "Fusing"
					else
						return "InMachine", ""
					end
				end
			end
		end
	end
	return "Default"
end

function Base.GetBase(player)
	return I[player]
end

function Base:Rebrith()
	local folder = self.Model and self.Model.Parent
	if self.Model and folder then
		self.Model.Parent:SetAttribute("Taken", false)
		self.Model.Parent:SetAttribute("Owner", nil)
		self.Model:Destroy()

		if I[self.player] then
			I[self.player] = nil
		end
	end
	return folder
end

function Base:GetFolder()
	if self and self.Owner then
		for i = 1, #Map.Base:GetChildren() do
			local folder = Map.Base:FindFirstChild(tostring(i))
			if folder and not folder:GetAttribute("Taken") then
				folder:SetAttribute("Taken", true)
				folder:SetAttribute("Owner", self.Owner)
				return folder
			end
		end
	end
end

local function GetBaseTemplateFolder()
	local baseFolder = ServerStorage:FindFirstChild("Base")
	if not baseFolder then
		baseFolder = Instance.new("Folder")
		baseFolder.Name = "Base"
		baseFolder.Parent = ServerStorage
	end

	return baseFolder
end

local function ResolveBaseTemplate(level)
	local baseFolder = GetBaseTemplateFolder()
	return baseFolder:FindFirstChild(tostring(level))
		or baseFolder:FindFirstChild("0")
		or baseFolder:FindFirstChildWhichIsA("Model")
end

local function BootstrapBaseTemplate(existingModel)
	if not existingModel or not existingModel:IsA("Model") then
		return nil
	end

	local baseFolder = GetBaseTemplateFolder()
	local template = baseFolder:FindFirstChild("0")
	if template then
		return template
	end

	template = existingModel:Clone()
	template.Name = "0"
	template.Parent = baseFolder
	return template
end

function Base:SetModel()
	local Folder: Folder = self:GetFolder()
	if not Folder then
		return
	end
	local ExistingModel = Folder:FindFirstChild("Base")
		or Folder:FindFirstChildWhichIsA("Model")
		or Folder:FindFirstChildOfClass("Model")
	local BaseTemplate = ResolveBaseTemplate(self.BaseLevel) or BootstrapBaseTemplate(ExistingModel)

	if not BaseTemplate then
		warn("[Base] No base template found in ServerStorage.Base and no fallback model exists in the map.")
		return nil
	end

	if ExistingModel then
		ExistingModel:Destroy()
	end

	local NewBase = BaseTemplate:Clone()
	NewBase.Name = "Base"
	NewBase.Parent = Folder
	NewBase:SetAttribute("Owner", self.Owner)

	if Folder:FindFirstChild("Spawn") then
		NewBase:PivotTo(Folder:FindFirstChild("Spawn").CFrame)
	end

	self.Model = NewBase
	local Bottom = NewBase:FindFirstChild("Bottom")
	self.StockBrainrot = Bottom and Bottom:FindFirstChild("StockBrainrot")
	self.LockPartFolder = Bottom and Bottom:FindFirstChild("LockPartFolder")

	if not self.StockBrainrot then
		warn("[Base] Base template is missing Bottom/StockBrainrot.")
	end
	return self.Model
end

function Base:RemoveAllBrainrot()
	if self.Model and self.StockBrainrot then
		for _, v in pairs(self.StockBrainrot:GetChildren()) do
			local model = v:FindFirstChildWhichIsA("Model") or v:FindFirstChildOfClass("Model")

			if model then
				model:Destroy()
			end

			v:SetAttribute("Enter", false)
		end
	end
end

function Base:Transparency()
	local LaserBottom = self.Model:FindFirstChild("LaserBottom")
	local Laser = LaserBottom and LaserBottom:WaitForChild("Laser")
	local Barrier = LaserBottom and LaserBottom:WaitForChild("Barrier")

	if Barrier and Laser then
		for _, part in pairs(Barrier:GetChildren()) do
			if part:IsA("BasePart") then
				part.CanCollide = self.Lookced
			end
		end
		for _, part in pairs(Laser:GetChildren()) do
			if part:IsA("BasePart") then
				part.Transparency = self.Lookced and 0 or 1
				part.CanCollide = false
			end
		end
	end
end

function Base:Lock(part)
	if not self.Model then
		return
	end
	self:Transparency()

	local function AddParts()
		if self.LockPartFolder then
			for _, part in pairs(self.LockPartFolder:GetChildren()) do
				CollectionService:AddTag(part, "TimeLockedBase")
				part:SetAttribute("UnlockTime", os.time() + self.TimeLock)

				if part:FindFirstChild("Info") then
					part.Info.AlwaysOnTop = false
				end
			end
			return true
		end
		return false
	end

	local function RemoveTime()
		if self.LockPartFolder then
			for _, part in pairs(self.LockPartFolder:GetChildren()) do
				CollectionService:RemoveTag(part, "TimeLockedBase")
			end
			return true
		end
		return false
	end

	part.Touched:Connect(function(hit)
		if hit and hit.Parent then
			if hit.Parent:FindFirstChild("Humanoid") and hit.Parent.Name == self.Owner then
				local char = hit.Parent
				if not Hits[char] then
					Hits[char] = true

					if self.Lookced then
						self.Lookced = false
						self:Transparency()

						if not AddParts() then
							CollectionService:AddTag(part, "TimeLockedBase")
							part:SetAttribute("UnlockTime", os.time() + self.TimeLock)
						end

						if self._unlockFlag then
							self._unlockFlag = false
						end

						self._unlockFlag = true
						task.spawn(function()
							local timer = self.TimeLock
							while timer > 0 and self._unlockFlag do
								timer -= 1
								task.wait(1)
							end
							if self._unlockFlag then
								self.Lookced = true
								if not RemoveTime() then
									CollectionService:RemoveTag(part, "TimeLockedBase")
								end
								self:Transparency()
							end
							self._unlockFlag = nil
						end)
					else
						MessageModule:SendMessage(
							self.player,
							"Your base is already unlocked !",
							2.5,
							Color3.new(1, 0, 0)
						)
					end

					task.delay(1, function()
						Hits[char] = nil
					end)
				end
			end
		end
	end)
end

function Base:BreakLock(part, value)
	if not self.Model then
		return
	end

	if self._unlockFlag then
		self._unlockFlag = false
	end

	if value then
		self.Lookced = true
		CollectionService:RemoveTag(part, "TimeLockedBase")
		self:Transparency()
	else
		self.Lookced = false
		self:Transparency()
		CollectionService:AddTag(part, "TimeLockedBase")
		part:SetAttribute("UnlockTime", os.time() + self.TimeLock)

		self._unlockFlag = true
		task.spawn(function()
			local timer = self.TimeLock
			while timer > 0 and self._unlockFlag do
				timer -= 1
				task.wait(1)
			end
			if self._unlockFlag then
				self.Lookced = true
				CollectionService:RemoveTag(part, "TimeLockedBase")
				self:Transparency()
			end
			self._unlockFlag = nil
		end)
	end
end

function Base:GetSlotRequire()
	local StockBrainrot = self.StockBrainrot
	local pos_found = nil

	if StockBrainrot then
		for _, pos in ipairs(StockBrainrot:GetChildren()) do
			if pos:GetAttribute("Enter") ~= true then
				pos_found = pos
				break
			end
		end
	end

	return pos_found
end

function Base:GetModelBySlots(position)
	if self.Model and self.StockBrainrot then
		local SlotModel: Model = self.StockBrainrot:FindFirstChild(position)
		if SlotModel then
			return SlotModel:FindFirstChildWhichIsA("Model") or SlotModel:FindFirstChildOfClass("Model")
		end
	end
end

function Base:ConfigureSlotPrompts(slotModel, brainrotModel)
	if not slotModel then
		return
	end

	local movePart = slotModel:FindFirstChild("MovePart")
	if movePart then
		local slotPromptRoot = CreatePromptRoot(slotModel, "SlotPromptRoot", movePart, GetSlotPromptCFrame(movePart))
		local attachPLACE = slotPromptRoot and CreateAttache(slotPromptRoot, "PlaceAttach", Vector3.new())
		createPrompt("Place Brainrot", attachPLACE, 0.5)
	end

	if not brainrotModel then
		DestroyPromptRoot(slotModel, "BrainrotPromptRoot")
		return
	end

	local promptCarrier = movePart or BrainrotSelect:EnsurePrimaryPart(brainrotModel)
	if not promptCarrier then
		warn("[Base] No prompt carrier found for brainrot:", brainrotModel.Name)
		return
	end

	local promptRootPart =
		CreatePromptRoot(slotModel, "BrainrotPromptRoot", promptCarrier, GetSlotPromptCFrame(promptCarrier))
	local placeAttach = promptRootPart and CreateAttache(promptRootPart, "PlaceAttach", Vector3.new())
	local DeleteAttach = promptRootPart and CreateAttache(promptRootPart, "DeleteAttach", Vector3.new(0, -2.1, 0))
	local StealAttach = promptRootPart and CreateAttache(promptRootPart, "StealAttach", Vector3.new(0, 0.35, 0))
	local ReturnAttach = promptRootPart and CreateAttache(promptRootPart, "ReturnAttach", Vector3.new(0, 0.7, 0))

	createPrompt("Place", placeAttach, 1)
	createPrompt("Steal", StealAttach, 1.5)
	local deletePrompt = createPrompt("Delete", DeleteAttach, 1)
	createPrompt("Return", ReturnAttach, 1)

	if deletePrompt then
		deletePrompt.KeyboardKeyCode = Enum.KeyCode.F
	end
end

function Base:RefreshExistingBrainrots()
	if not self.StockBrainrot then
		return
	end

	for _, slotModel in pairs(self.StockBrainrot:GetChildren()) do
		local brainrotModel = slotModel:FindFirstChildWhichIsA("Model") or slotModel:FindFirstChildOfClass("Model")
		slotModel:SetAttribute("Owner", self.Owner)

		if brainrotModel then
			local position = tostring(brainrotModel:GetAttribute("Position") or slotModel.Name)
			local success, mode = self:GetMode(position)
			local brainrotData = ServiceTable["DataManager"].GetBrainrot(self.player, position)

			slotModel:SetAttribute("Enter", true)
			brainrotModel:SetAttribute("Position", position)
			brainrotModel:SetAttribute("Owner", self.Owner)
			brainrotModel:SetAttribute("Mutation", brainrotModel:GetAttribute("Mutation") or "Normal")
			brainrotModel:SetAttribute("Type", success)
			brainrotModel:SetAttribute("Mode", mode or "")

			BrainrotSelect:PreparePlacedModel(brainrotModel)
			BrainrotSelect:ClearProximityPrompt(brainrotModel)

			if slotModel:FindFirstChild("MovePart") then
				brainrotModel:PivotTo(slotModel.MovePart.CFrame)
			end

			if brainrotData then
				BrainrotSelect:SetInfoByBrairot(
					brainrotModel,
					brainrotModel:GetAttribute("Mutation") or "Normal",
					brainrotData.Slots
				)
			end

			BrainrotSelect:SetInfoByMode(brainrotModel, { success, mode or "" }, brainrotData)
			self:ConfigureSlotPrompts(slotModel, brainrotModel)
			GlobalEvent:FireAllClients("FlyBrainrot", brainrotModel)
		else
			slotModel:SetAttribute("Enter", false)
			self:ConfigureSlotPrompts(slotModel, nil)
		end
	end
end

local function IsDepositCarryState(char)
	if not char then
		return false
	end

	local carryType = char:GetAttribute("Type")
	return char:GetAttribute("InPlace") ~= true and (carryType == "Buy" or carryType == "Steal")
end

local function IsCharacterInsidePart(char, part)
	if not (char and part) then
		return false
	end

	for _, touchedPart in ipairs(Workspace:GetPartsInPart(part)) do
		if touchedPart:IsDescendantOf(char) then
			return true
		end
	end

	return false
end

function Base:TryDepositCarriedBrainrot(char)
	if not (char and char:FindFirstChildOfClass("Humanoid")) then
		return false
	end

	if char.Name ~= self.Owner or self.Lookced or not IsDepositCarryState(char) then
		return false
	end

	local PositionSelect = self:GetSlotRequire(self.Model)
	local BrairotInfo = BrainrotSelect:GetInfo(char)
	local player = Players:GetPlayerFromCharacter(char)

	if not PositionSelect then
		if player then
			MessageModule:SendMessage(player, "Base full !", 2, Color3.new(1, 0, 0))
		end
		return false
	end

	if not (player and BrainrotSelect and BrairotInfo) then
		return false
	end

	ServiceTable["DataManager"].AddBrainrot(
		player,
		BrairotInfo.Name,
		BrairotInfo.Mutation,
		BrairotInfo.Slots,
		PositionSelect.Name
	)

	self.UpdateBrairot:Fire(
		BrairotInfo.Name,
		BrairotInfo.Mutation,
		PositionSelect.Name,
		BrairotInfo.Slots,
		0
	)

	if char:GetAttribute("Type") == "Steal" then
		local PlaceBrainrot = BrainrotSelect:GetPlace(char)
		if PlaceBrainrot then
			local owner = PlaceBrainrot:GetAttribute("Owner")
			local playerFound = Players:FindFirstChild(owner)
			if playerFound then
				ServiceTable["DataManager"].RemoveBrainrot(playerFound, PlaceBrainrot:GetAttribute("Position"))
				MessageModule:SendMessage(
					playerFound,
					`{char.Name} has stolen your brainrot {BrairotInfo.Name}`,
					3.5
				)

				local profile = ServiceTable["DataManager"]:GetProfile(playerFound)
				local Data = profile and profile.Data

				if Data then
					if PlaceBrainrot:GetAttribute("Mode") == "AuraSpin" then
						ServiceTable["DataManager"]:ClearAuraSpin(playerFound)
					end
				else
					warn("Pas de Data !")
				end
			end
			MessageModule:SendMessage(player, `You are stol {BrairotInfo.Name}`, 2.5)
			PlaceBrainrot:Destroy()
		end
		char:SetAttribute("InPlace", false)
		char:SetAttribute("Type", "")
	end

	ServiceTable["DataManager"].AddIndex(player, BrairotInfo.Name, BrairotInfo.Mutation)

	char:SetAttribute("Type", "None")
	BrainrotSelect:UnGrab(char)
	BrainrotSelect:RemoveInfo(char)
	BrainrotSelect:RemovePlace(char)
	BrainrotSelect:ClearGrab(char)

	return true
end

function Base:ModelAsset()
	if self.Model and self.StockBrainrot then
		if self.LockPartFolder then
			for _, part in pairs(self.LockPartFolder:GetChildren()) do
				self:Lock(part)
			end
		end

		if self.Model:WaitForChild("Bottom"):FindFirstChild("LockPart") then
			self:Lock(self.Model:WaitForChild("Bottom"):WaitForChild("LockPart"))
		end

		local Hitbox = self.Model:FindFirstChild("Hitbox")

		for _, slotModel in pairs(self.StockBrainrot:GetChildren()) do
			slotModel:SetAttribute("Enter", false)
			slotModel:SetAttribute("Owner", self.Owner)

			self:ConfigureSlotPrompts(slotModel, nil)

			slotModel:GetAttributeChangedSignal("Enter"):Connect(function()
				if slotModel:GetAttribute("Enter") == false then
					DestroyPromptRoot(slotModel, "BrainrotPromptRoot")
					if slotModel:GetAttribute("Owner") == self.player.Name then
						ProximityPromptEvent:FireClient(self.player, "Visible", "Brairot Place")
					end
				end
			end)
		end

		if Hitbox then
			local function ScheduleTouchDebounce(char)
				Hits[char] = true
				task.delay(1, function()
					Hits[char] = false
				end)
			end

			local function TryDepositFromCharacterState(char)
				if not (char and char:FindFirstChildOfClass("Humanoid")) then
					return false
				end

				if char.Name ~= self.Owner or Hits[char] then
					return false
				end

				local carryingForDeposit = IsDepositCarryState(char)
				local movingBaseBrainrot = char:GetAttribute("InPlace") == true

				if not carryingForDeposit and not movingBaseBrainrot then
					return false
				end

				ScheduleTouchDebounce(char)

				if self.Lookced then
					MessageModule:SendMessage(
						self.player,
						"Unlock your base to add brainrots",
						2.5,
						Color3.new(1, 0, 0)
					)
					return false
				end

				if carryingForDeposit then
					return self:TryDepositCarriedBrainrot(char)
				end

				return false
			end

			local function BindCharacterDepositCheck(char)
				if not char then
					return
				end

				char:GetAttributeChangedSignal("Type"):Connect(function()
					local carryType = char:GetAttribute("Type")
					if carryType ~= "Buy" and carryType ~= "Steal" then
						return
					end

					task.defer(function()
						if char.Parent and IsCharacterInsidePart(char, Hitbox) then
							TryDepositFromCharacterState(char)
						end
					end)
				end)
			end

			Hitbox.Touched:Connect(function(hit)
				local char: Model = hit and hit.Parent

				TryDepositFromCharacterState(char)
			end)

			BindCharacterDepositCheck(self.player.Character)
			self.player.CharacterAdded:Connect(BindCharacterDepositCheck)
		end
	end
end

function Base:Info()
	if self.Model and self.Owner then
		local Sign = self.Model:FindFirstChild("Sign")
		local CollectZone = self.Model:FindFirstChild("CollectZone")
		if Sign then
			local SignLabel = Sign:WaitForChild("SignGUI"):WaitForChild("SignLabel")
			SignLabel.Text = self.Owner or self.player and self.player.Name
		end
		if CollectZone then
			local Spawner = CollectZone:FindFirstChild("Spawner")
			local CashMultiGui = RP.Gui.CashMulti:Clone()
			if Spawner then
				CashMultiGui.Parent = Spawner
				CashMultiGui.Label.Text = "x" .. tostring(self.Multiplicateur)
			end
		end
	else
		warn("Error!")
	end
end

function Base:ApplyBrainrot()
	if self.player then
		local profile = ServiceTable["DataManager"]:GetProfile(self.player)
		local data = self.Data or profile and profile.Data
		if not data then
			return
		end

		local BaseData = data.Base
		local Brainrots = BaseData.Brainrot

		for _, brainrot in pairs(Brainrots) do
			self.UpdateBrairot:Fire(
				brainrot.Name,
				brainrot.Mutation,
				brainrot.Position,
				brainrot.Slots,
				brainrot.HorsLineCash
			)
		end
	end
end

------------------------------
-----///Signal Apply//-----
------------------------------

function Base:SignalApply()
	------------------------------
	----///Upgrade Brainrot///----
	------------------------------

	self.CashUpdate:Connect(function(model)
		if self.player then
			if model:GetAttribute("Owner") == self.player.Name then
				local CashFinal = model:GetAttribute("CashFinal") or 1
				model:GetAttribute("CurrentCash", 0)
			end
		end
	end)

	self.UpdateBrairot.Event:Connect(function(name, mutation, position, slots, cash)
		if self.Model and self.StockBrainrot and name then
			local SlotSelect = self.StockBrainrot:FindFirstChild(position)
			local succes, mode = self:GetMode(position)

			if SlotSelect and not SlotSelect:GetAttribute("Enter") then
				local NewBrairot = BrainrotSelect:GetBrainrot(name, mutation)
				if not NewBrairot then
					warn("Not Brainrot fount by name [" .. tostring(name) .. "]")
					return
				end

				NewBrairot.Parent = SlotSelect
				BrainrotSelect:PreparePlacedModel(NewBrairot)
				BrainrotSelect:ClearProximityPrompt(NewBrairot)

				NewBrairot:SetAttribute("Position", position)
				NewBrairot:SetAttribute("Mutation", mutation)
				NewBrairot:SetAttribute("Owner", self.Owner)
				NewBrairot:SetAttribute("InFuse", false)

				SlotSelect:SetAttribute("Enter", true)
				SlotSelect:SetAttribute("CurrentCash", cash or 0)

				NewBrairot:SetAttribute("Type", succes)
				NewBrairot:SetAttribute("Mode", mode or "")

				GlobalEvent:FireAllClients("FlyBrainrot", NewBrairot)

				if SlotSelect:FindFirstChild("MovePart") then
					NewBrairot:PivotTo(SlotSelect.MovePart.CFrame)
				end

				BrainrotSelect:SetInfoByBrairot(NewBrairot, mutation, slots)

				BrainrotSelect:SetInfoByMode(NewBrairot, { succes, mode } or "")

				local function UpdateAsset()
					local brairotData =
						ServiceTable["DataManager"].GetBrainrot(self.player, NewBrairot:GetAttribute("Position"))
					BrainrotSelect:SetInfoByMode(
						NewBrairot,
						{ NewBrairot:GetAttribute("Type"), NewBrairot:GetAttribute("Mode") or "" },
						brairotData
					)
				end

				NewBrairot:GetAttributeChangedSignal("Mode"):Connect(UpdateAsset)

				NewBrairot:GetAttributeChangedSignal("Type"):Connect(UpdateAsset)

				self:ConfigureSlotPrompts(SlotSelect, NewBrairot)

				AddCash:Fire("Add", NewBrairot)
			end
		end
	end)
end

------------------------------
------///Base Remove///-------
------------------------------

function Base:Removing(player)
	local NewBase = Base.GetBase(player)
	if NewBase then
		if NewBase.StockBrainrot then
			local profile = ServiceTable["DataManager"]:GetProfile(player)
			local data = profile and profile.Data
			local releasedSources = BrainrotSelect:ReleaseOwnerReferences(NewBase.Owner)

			if data then
				for index = #data.Base.Brainrot, 1, -1 do
					local value = data.Base.Brainrot[index]
					if value and value.Name then
						local SlotModel = NewBase.StockBrainrot:FindFirstChild(value.Position)
						if SlotModel then
							local brairotModel = SlotModel:FindFirstChild(value.Name)
							if brairotModel then
								local mode = brairotModel:GetAttribute("Mode")
								if mode == "InSteal" or mode == "DroppedCarry" or releasedSources[brairotModel] then
									if not releasedSources[brairotModel] then
										BrainrotSelect:CreateAbandonedDrop(brairotModel, value)
									end
									ServiceTable.DataManager.RemoveBrainrot(player, value.Position)
								end
							else
								ServiceTable.DataManager.RemoveBrainrot(player, value.Position)
							end
						else
							ServiceTable.DataManager.RemoveBrainrot(player, value.Position)
						end
					end
				end
			end
		end

		if NewBase.Model then
			local template = ResolveBaseTemplate(0)
			if template then
				local model = template:Clone()
				model.Name = "Base"
				model.Parent = NewBase.Model.Parent
				model:PivotTo(NewBase.Model:GetPivot())
				NewBase.Model:Destroy()
			else
				NewBase:RemoveAllBrainrot()
				NewBase.Model:SetAttribute("Owner", nil)
			end
		end
		for _, folder in pairs(Map.Base:GetChildren()) do
			if folder:GetAttribute("Owner") == NewBase.Owner then
				folder:SetAttribute("Taken", false)
				folder:SetAttribute("Owner", nil)
			end
		end
	end
end

----------------------------------
-----///InitialisationBase///-----
----------------------------------

function Base:Init()
	if self.player and self.Model and self.StockBrainrot then
		self.UpgradeBase:Connect(function()
			print("True")
		end)

		self:SignalApply()
		self:ModelAsset()
		self:ApplyBrainrot()
		self:RefreshExistingBrainrots()
		self:Info()
		task.wait()
	else
		warn("Init not work")
	end
end

return Base
