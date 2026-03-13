-- PromptManager.lua (Client)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PromptManager = {}

--------------------------------------------------
-- STATE
--------------------------------------------------

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local characterStateConnection = nil

local currentPrompt = nil
local prompts = {}
local Modelprompts = {}
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local PROMPT_REFRESH_INTERVAL = GameConfig.Prompts.RefreshInterval
local promptRefreshAccumulator = 0
local promptRefreshDirty = true

local Gui = require(game.ReplicatedStorage.MyService.Service.Gui)

--------------------------------------------------
-- UTILS
--------------------------------------------------

local function getParentFromPrompt(prompt, arg1)
	local ISA : string = arg1 or "Model"
	local p = prompt.Parent
	while p and not p:IsA(ISA) do
		p = p.Parent
	end
	return p
end

local function getPromptKey(prompt)
	return (prompt.Name ~= "" and prompt.Name) or prompt.ActionText
end

local function getSlotBrainrotModel(slotModel)
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

local function getPromptContainerModel(prompt)
	return getParentFromPrompt(prompt)
end

local function getPromptTargetModel(prompt, promptModel)
	if not promptModel then
		return nil
	end

	if prompt.ActionText == "Place Brainrot" then
		return promptModel
	end

	if promptModel:GetAttribute("Enter") ~= nil then
		return getSlotBrainrotModel(promptModel) or promptModel
	end

	return promptModel
end

local function cacheModelPrompts(model)
	if not model then
		return
	end

	if Modelprompts[model] then
		return
	end

	Modelprompts[model] = {}

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			Modelprompts[model][getPromptKey(descendant)] = descendant
		end
	end
end

local function VisiblePrompt(model, actionText, value)
	cacheModelPrompts(model)

	if Modelprompts[model] and Modelprompts[model][actionText] then
		Modelprompts[model][actionText].Enabled = value
	end
end

local function VisibleList(model, list, value)
	for _, v in pairs(list) do
		VisiblePrompt(model, v, value)
	end
end

local function getModelState(model)
	if not model then
		return "Default"
	end

	local mode = model:GetAttribute("Mode")
	if model:GetAttribute("Type") == "InMachine" or mode == "AuraSpin" or mode == "Fusion" or mode == "InFuse" then
		return "InMachine"
	end
	if mode == "Fusing" then
		return "Fusing"
	end
	return "Default"
end

local function isAuraMachineModel(model)
	return model and model:GetAttribute("Mode") == "AuraSpin"
end

local function UnVisible()
	local MainGui = Gui:GetGuiByName("MainGui")
	local RollGui = Gui:GetGuiByName("RollGui")
	local WhiteList = { "AuraSpin", "FuseMachine", "ToolShop", "RobuxShop" }
	if not MainGui then return end
	local allowed = {}
	for _, name in ipairs(WhiteList) do
		allowed[name] = true
	end
	for _, guiObject in ipairs(MainGui:GetChildren()) do
		if allowed[guiObject.Name] and guiObject.Visible then
			Gui:AnimFrame(guiObject, false)
			RollGui.Enabled = true
		end
	end
end

--------------------------------------------------
-- PROMPT LOGIC
--------------------------------------------------

local WhiteListMode = { Steal = true, Place = true, Fusion = true }

local PromptPriority = {
	Return = 1,
	Place = 2,
	Delete = 3,
	Steal = 4,
	["Pick Up"] = 4,
	["Place Brainrot"] = 5,
	Open = 6,
	Special = 0,
}

local function getPromptPriority(prompt)
	return PromptPriority[prompt.ActionText] or PromptPriority[prompt.Name] or 99
end

local function canCharacterUsePrompts()
	if not (character and character.Parent) then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil
		and humanoid.Health > 0
		and humanoid:GetState() ~= Enum.HumanoidStateType.Dead
end

local function refreshPrompt(prompt)
	if not prompt or not prompt:IsDescendantOf(game) then
		return
	end
	
	local promptModel = getPromptContainerModel(prompt)
	local model = getPromptTargetModel(prompt, promptModel)
	if not promptModel or not model then
		prompt.Enabled = false
		return
	end
	
	if not Modelprompts[promptModel] then
		Modelprompts[promptModel] = {}
	end
	
	cacheModelPrompts(promptModel)
	Modelprompts[promptModel][getPromptKey(prompt)] = prompt

	local owner = model:GetAttribute("Owner") == player.Name
	local state = getModelState(model)
	local mode = model:GetAttribute("Mode")
	local slotEnter = promptModel:GetAttribute("Enter")

	prompt.Enabled = false
	VisibleList(promptModel, { "Return", "Delete", "Place", "Steal", "Place Brainrot" }, false)

	if not canCharacterUsePrompts() then
		return
	end

	if prompt.Name == "Special" then
		prompt.Enabled = true
		return
	end

	if mode == "InSteal" or mode == "DroppedCarry" then
		return
	end

	--------------------------------------------------
	-- FUSING
	--------------------------------------------------
	if state == "Fusing" then
		return
	end

	--------------------------------------------------
	-- IN MACHINE
	--------------------------------------------------
	
	if state == "InMachine" then
		if mode == "Fusion" then
			prompt.Enabled = false
			return
		end
		if owner and isAuraMachineModel(model) then
			VisiblePrompt(promptModel, "Return", true)
			VisibleList(promptModel, { "Delete", "Place", "Steal", "Place Brainrot" }, false)
		elseif owner then
			VisibleList(promptModel, { "Return", "Delete", "Place", "Steal", "Place Brainrot" }, false)
		else
			VisibleList(promptModel, { "Return", "Delete", "Place", "Place Brainrot" }, false)
			VisiblePrompt(promptModel, "Steal", true)
		end
		return
	elseif state == "Default" then
		if owner then
			VisiblePrompt(promptModel, "Steal", false)
			VisiblePrompt(promptModel, "Return", false)
			VisiblePrompt(
				promptModel,
				"Place",
				character:GetAttribute("InPlace") or not character:GetAttribute("Grab")
			)
			VisiblePrompt(
				promptModel,
				"Delete",
				not character:GetAttribute("Grab") and not character:GetAttribute("InPlace")
			)
		else
			VisibleList(promptModel, { "Return", "Delete", "Place", "Place Brainrot" }, false)
			VisiblePrompt(promptModel, "Steal", not character:GetAttribute("Grab") and not character:GetAttribute("InPlace"))
		end
	end

	--------------------------------------------------
	-- DEFAULT
	--------------------------------------------------
	if prompt.ActionText == "Open" then
		prompt.Enabled = model:GetAttribute("Type") == "LuckyBlock"

	elseif prompt.ActionText == "Steal" then
		prompt.Enabled = not owner and not character:GetAttribute("InPlace") and not character:GetAttribute("Grab")

	elseif prompt.ActionText == "Place" then
		prompt.Enabled = owner and (character:GetAttribute("InPlace") or not character:GetAttribute("Grab"))

	elseif prompt.ActionText == "Delete" then
		prompt.Enabled = owner and not character:GetAttribute("InPlace") and not character:GetAttribute("Grab")
	elseif prompt.ActionText == "Place Brainrot" then
		prompt.Enabled =
			owner
			and character:GetAttribute("InPlace")
			and slotEnter == false
	elseif prompt.ActionText == "Pick Up" then
		prompt.Enabled =
			model:GetAttribute("Dropped") == true
			and (model:GetAttribute("DropPickupOwner") == nil or model:GetAttribute("DropPickupOwner") == player.Name)
			and not character:GetAttribute("InPlace")
			and not character:GetAttribute("Grab")
	else
		prompt.Enabled = false
	end
	
	if character:GetAttribute("InPlace") and owner then
		VisiblePrompt(promptModel, "Delete", false)
	end
	
end

--------------------------------------------------
-- PROMPT DETECTION
--------------------------------------------------

local function registerPrompt(prompt)
	if not prompt:IsA("ProximityPrompt") then return end
	if table.find(prompts, prompt) then return end
	table.insert(prompts, prompt)

	local promptModel = getPromptContainerModel(prompt)
	if promptModel then
		Modelprompts[promptModel] = Modelprompts[promptModel] or {}
		Modelprompts[promptModel][getPromptKey(prompt)] = prompt
	end

	promptRefreshDirty = true
end

local function removePrompt(prompt)
	local index = table.find(prompts, prompt)
	if index then table.remove(prompts, index) end

	local promptModel = getPromptContainerModel(prompt)
	if promptModel and Modelprompts[promptModel] then
		Modelprompts[promptModel][getPromptKey(prompt)] = nil
		if next(Modelprompts[promptModel]) == nil then
			Modelprompts[promptModel] = nil
		end
	end

	if currentPrompt == prompt then
		currentPrompt = nil
	end

	promptRefreshDirty = true
end

local function scanPrompts()
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("ProximityPrompt") then
			registerPrompt(obj)
		end
	end
end

local function watchPrompts()
	workspace.DescendantAdded:Connect(function(obj)
		if obj:IsA("ProximityPrompt") then
			registerPrompt(obj)
		end
	end)
	workspace.DescendantRemoving:Connect(function(obj)
		if obj:IsA("ProximityPrompt") then
			removePrompt(obj)
		end
	end)
end

local function getClosestPrompt()
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local closestPrompt = nil
	local closestDistance = math.huge
	local closestPriority = math.huge
	for _, prompt in ipairs(prompts) do
		if prompt:IsDescendantOf(game) then
			refreshPrompt(prompt)
			local part = getParentFromPrompt(prompt, "BasePart")
			if prompt.Enabled and part then
				local dist = (root.Position - part.Position).Magnitude
				local priority = getPromptPriority(prompt)
				if dist <= prompt.MaxActivationDistance
					and (
						dist < closestDistance - 0.05
						or (math.abs(dist - closestDistance) <= 0.05 and priority < closestPriority)
					)
				then
					closestDistance = dist
					closestPriority = priority
					closestPrompt = prompt
				end
			end
		end
	end
	return closestPrompt
end

local function syncVisiblePromptGroup(closestPrompt)
	local closestContainer = closestPrompt and getPromptContainerModel(closestPrompt)

	for _, prompt in ipairs(prompts) do
		if prompt and prompt:IsDescendantOf(game) then
			if not closestPrompt then
				prompt.Enabled = false
			else
				local promptContainer = getPromptContainerModel(prompt)
				if promptContainer ~= closestContainer then
					prompt.Enabled = false
				end
			end
		end
	end
end

--------------------------------------------------
-- LOOP
--------------------------------------------------

local function update(dt)
	promptRefreshAccumulator += dt or 0
	if not promptRefreshDirty and promptRefreshAccumulator < PROMPT_REFRESH_INTERVAL then
		return
	end

	promptRefreshAccumulator = 0
	promptRefreshDirty = false

	local closest = getClosestPrompt()
	syncVisiblePromptGroup(closest)

	if closest ~= currentPrompt then
		if currentPrompt then
			UnVisible()
		end
		currentPrompt = closest
	end
end

local function bindCharacter(newChar)
	character = newChar
	currentPrompt = nil

	if characterStateConnection then
		characterStateConnection:Disconnect()
		characterStateConnection = nil
	end

	characterStateConnection = character.AttributeChanged:Connect(function(attributeName)
		if attributeName ~= "InPlace" and attributeName ~= "Grab" then
			return
		end

		promptRefreshDirty = true
		if currentPrompt then
			refreshPrompt(currentPrompt)
		end
	end)
end

--------------------------------------------------
-- INIT
--------------------------------------------------

function PromptManager:Init()
	player = Players.LocalPlayer
	bindCharacter(player.Character or player.CharacterAdded:Wait())
	scanPrompts()
	watchPrompts()
	task.delay(1, function()
		for _, prompt in ipairs(prompts) do
			refreshPrompt(prompt)
		end
		promptRefreshDirty = true
	end)
	RunService.Heartbeat:Connect(update)
	player.CharacterAdded:Connect(bindCharacter)
end

return PromptManager
