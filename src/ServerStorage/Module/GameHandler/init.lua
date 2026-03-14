local Players = game:GetService("Players")
local MessagingService = game:GetService("MessagingService")
local GameHandler = {}

local DataManager = require(game.ServerStorage.Data.DataManager)
local AuraSpinController = require(script.AuraSpinController)
local MessageModule = require(game.ReplicatedStorage.Module.MessageModule)
local ProximityPrompt = require(script.ProximityPrompt)
local BrainrotSelect = require(game.ServerStorage.Module.BrainrotSelect)
local Machine = require(script.Machine)
local MapMutationManager = require(game.ServerStorage.Module.MapMutationManager)
local ServerRestartManager = require(game.ServerStorage.Module.ServerRestartManager)
local ServerLuckManager = require(game.ServerStorage.Module.ServerLuckManager)

local GuiList = require(game.ReplicatedStorage:WaitForChild("List"):WaitForChild("GuiList"))
local GlobaleEvent = game.ReplicatedStorage.Events.RemoteEvents.GlobaleEvent

local ServerLuck = game.ServerScriptService.Server.LuckServer
local GLOBAL_MAP_MUTATION_TOPIC = "GlobalMapMutationEvent"
local GLOBAL_ADMIN_ABUSE_TOPIC = "GlobalAdminAbuseEvent"
local GLOBAL_SERVER_RESTART_TOPIC = ServerRestartManager.GLOBAL_TOPIC
local GLOBAL_FUSE_TIME_TOPIC = "GlobalFuseTimeEvent"
local initialized = false
local promptWatchStarted = false
local FORCE_NO_LINE_OF_SIGHT_ATTRIBUTE = "ForceNoLineOfSight"

local function UpdateLuckBuff(player)
	ServerLuckManager:Init()
	ServerLuckManager:RefreshClient(player)
end

local function Collisiongroup(model, name)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			pcall(function()
				part.CollisionGroup = name
			end)
		end
	end
end

local function applyPromptLineOfSight(prompt)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return
	end

	prompt.RequiresLineOfSight = prompt:GetAttribute(FORCE_NO_LINE_OF_SIGHT_ATTRIBUTE) ~= true
end

local function watchPrompts()
	if promptWatchStarted then
		return
	end

	promptWatchStarted = true
	
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("ProximityPrompt") then
			applyPromptLineOfSight(obj)
		end
	end

	workspace.DescendantAdded:Connect(function(obj)

		if obj:IsA("ProximityPrompt") then
			applyPromptLineOfSight(obj)
		end

	end)

	

end

local function ensureLivesFolder()
	local livesFolder = workspace:FindFirstChild("Lives")
	if livesFolder then
		return livesFolder
	end

	livesFolder = Instance.new("Folder")
	livesFolder.Name = "Lives"
	livesFolder.Parent = workspace
	return livesFolder
end

local function RestoreCarriedBrainrot(char)
	if not char then
		return
	end

	local BrainrotGrab = BrainrotSelect:GetGrabModel(char)
	local BrainrotPlace = BrainrotSelect:GetPlace(char)
	local carryType = char:GetAttribute("Type")

	if BrainrotGrab and carryType == "Steal" then
		BrainrotSelect:RestoreSteal(char)
		return
	end

	if BrainrotGrab and carryType == "Buy" then
		BrainrotSelect:DropCarry(char)
		return
	end

	if BrainrotGrab and carryType == "InPlace" then
		local player = Players:GetPlayerFromCharacter(char)
		local brainrotData = nil

		if player and BrainrotPlace then
			local position = BrainrotPlace:GetAttribute("Position")
			if position then
				brainrotData = DataManager.GetBrainrot(player, position)
			end
		end

		local grabbedModel = BrainrotSelect:UnGrab(char, true)
		if grabbedModel then
			grabbedModel:Destroy()
		end

		if BrainrotPlace then
			BrainrotPlace:SetAttribute("InPlace", false)
			BrainrotPlace:SetAttribute("Type", "Default")
			BrainrotPlace:SetAttribute("Mode", "")
			BrainrotSelect:SetInfoByMode(BrainrotPlace, { "Default", "" }, brainrotData)
		end

		BrainrotSelect:ClearGrab(char)
		BrainrotSelect:RemoveInfo(char)
		BrainrotSelect:RemovePlace(char)

		char:SetAttribute("Grab", false)
		char:SetAttribute("InPlace", false)
		char:SetAttribute("Type", "None")
		return
	end

	if BrainrotPlace then
		BrainrotPlace:SetAttribute("InPlace", false)
		BrainrotPlace:SetAttribute("Type", "Default")
		BrainrotPlace:SetAttribute("Mode", "")
		BrainrotSelect:SetInfoByMode(BrainrotPlace, {"Default", ""})
	end

	if BrainrotGrab then
		BrainrotSelect:UnGrab(char)
	end

	BrainrotSelect:ClearGrab(char)
	BrainrotSelect:RemoveInfo(char)
	BrainrotSelect:RemovePlace(char)

	char:SetAttribute("Grab", false)
	char:SetAttribute("InPlace", false)
	char:SetAttribute("Type", "None")
end

local function setupCharacter(player, char)
	local livesFolder = ensureLivesFolder()
	local Humanoid = char:WaitForChild("Humanoid")
	local cleaned = false

	local function cleanupOnce()
		if cleaned then
			return
		end

		cleaned = true
		RestoreCarriedBrainrot(char)
	end

	char.Parent = livesFolder
	Humanoid.WalkSpeed = 28

	Collisiongroup(char, "Players")

	if char:GetAttribute("Ragdoll") == nil then
		char:SetAttribute("Ragdoll", false)
	end

	if char:GetAttribute("InPlace") == nil then
		char:SetAttribute("InPlace", false)
	end

	char:GetAttributeChangedSignal("Ragdoll"):Connect(function()
		if char:GetAttribute("Ragdoll") then
			RestoreCarriedBrainrot(char)
		end
	end)

	Humanoid.Died:Connect(cleanupOnce)
	char.Destroying:Connect(cleanupOnce)
end

local function initGlobalSystems()
	if initialized then
		return
	end

	initialized = true
	ServerLuckManager:Init()
	ProximityPrompt:Init(DataManager)
	AuraSpinController:Init()
	Machine:Init()
	watchPrompts()
end

local function setupPlayer(player)
	initGlobalSystems()

	UpdateLuckBuff(player)
	Machine:Init(player)

	if player.Character then
		task.spawn(setupCharacter, player, player.Character)
	end

	player.CharacterAdded:Connect(function(char)
		setupCharacter(player, char)
		task.defer(function()
			if player.Parent then
				UpdateLuckBuff(player)
			end
		end)
		task.delay(1, function()
			if player.Parent then
				UpdateLuckBuff(player)
			end
		end)
	end)
end

Players.PlayerAdded:Connect(function(player)
	setupPlayer(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	
end)

MessagingService:SubscribeAsync("GlobalLuckEvent", function(data)
	
	local info = data.Data

	ServerLuckManager:Init()
	ServerLuck.Value = info.Luck

	local currentTime = ServerLuck:GetAttribute("Time") or 0
	ServerLuck:SetAttribute("Time", currentTime + info.Time)

	ServerLuckManager:RefreshClients()

	for _, player in pairs(Players:GetPlayers()) do
		MessageModule:SendMessage(player, info.Message, 2.5, Color3.new(1,1,1))
	end
	
	
end)

MessagingService:SubscribeAsync(GLOBAL_MAP_MUTATION_TOPIC, function(data)
	local info = data.Data
	if not info or info.SourceJobId == game.JobId then
		return
	end

	local success, message = MapMutationManager:ApplyAdminMutation(info.Mutation)
	if not success then
		warn("[GlobalMapMutationEvent] Apply failed:", message)
		return
	end

	if info.ExecutorName then
		local announcement = string.format("%s a applique la map %s globalement.", info.ExecutorName, tostring(info.Mutation))
		for _, player in ipairs(Players:GetPlayers()) do
			MessageModule:SendMessage(player, announcement, 2.5, Color3.new(1, 1, 1))
		end
	end
end)

MessagingService:SubscribeAsync(GLOBAL_ADMIN_ABUSE_TOPIC, function(data)
	local info = data.Data
	if not info or info.SourceJobId == game.JobId then
		return
	end

	local success, message = MapMutationManager:ApplyAdminAbuse(info.Abuse)
	if not success then
		warn("[GlobalAdminAbuseEvent] Apply failed:", message)
		return
	end

	if info.ExecutorName then
		local announcement = string.format("%s a active l'admin abuse %s globalement.", info.ExecutorName, tostring(info.Abuse))
		for _, player in ipairs(Players:GetPlayers()) do
			MessageModule:SendMessage(player, announcement, 2.5, Color3.new(1, 1, 1))
		end
	end
end)

MessagingService:SubscribeAsync(GLOBAL_SERVER_RESTART_TOPIC, function(data)
	local info = data.Data
	if not info or info.SourceJobId == game.JobId then
		return
	end

	local success, message = ServerRestartManager:RestartLocal(info.ExecutorName or "Console", "Global")
	if not success then
		warn("[GlobalServerRestartEvent] Restart failed:", message)
	end
end)

MessagingService:SubscribeAsync(GLOBAL_FUSE_TIME_TOPIC, function(data)
	local info = data.Data
	if not info or info.SourceJobId == game.JobId then
		return
	end

	local updatedCount = 0

	for _, player in ipairs(Players:GetPlayers()) do
		local machine = Machine:Return() or Machine:Init(player)
		if machine then
			local success = machine:SetFuseRemainingTime(player, info.Seconds)
			if success then
				updatedCount += 1
			end
		end
	end

	if updatedCount > 0 and info.ExecutorName then
		local announcement = string.format("%s a modifie le temps des fusions globalement.", info.ExecutorName)
		for _, player in ipairs(Players:GetPlayers()) do
			MessageModule:SendMessage(player, announcement, 2.5, Color3.new(1, 1, 1))
		end
	end
end)

function GameHandler:Init()
	
end

return GameHandler
