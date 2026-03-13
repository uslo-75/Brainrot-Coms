local GetInfo = {}
local Players = game:GetService("Players")
local RP = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local IndexList = require(game.ServerStorage.List.IndexList)
local DataManager = require(game.ServerStorage.Data.DataManager)
local AuraList = require(game.ServerStorage.List.AuraList)
local UpgradeList = require(game.ServerStorage.List.UpgradeList)
local BrairotList = require(game.ServerStorage.List.BrainrotList)
local MutationModule = require(game.ServerStorage.Module.RollModule.Mutation)
local PassId = require(game.ServerStorage.List.PassId)
local GameConfig = require(RP:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local DEFAULT_WAIT_TIMEOUT = GameConfig.Shared.DefaultWaitTimeout
local PREVIEW_DEBUG = false
local MAX_PREVIEW_KEY_LENGTH = GameConfig.Preview.KeyMaxLength
local MAX_PREVIEW_NAME_LENGTH = GameConfig.Preview.NameMaxLength
local MAX_SKIP_BRAINROT = GameConfig.Data.MaxSkipBrainrot

local PreviewCache = RP:FindFirstChild("PreviewCache")
if not PreviewCache then
	PreviewCache = Instance.new("Folder")
	PreviewCache.Name = "PreviewCache"
	PreviewCache.Parent = RP
end

local function waitForChildQuiet(parent, childName, timeout)
	local deadline = os.clock() + (timeout or DEFAULT_WAIT_TIMEOUT)
	local child = parent and parent:FindFirstChild(childName)

	while parent and not child and os.clock() < deadline do
		task.wait(0.1)
		child = parent:FindFirstChild(childName)
	end

	return child
end

local function getLeaderstat(player, statName, timeout)
	local leaderstats = player:FindFirstChild("leaderstats") or waitForChildQuiet(player, "leaderstats", timeout)
	if not leaderstats then
		return nil
	end

	return leaderstats:FindFirstChild(statName) or waitForChildQuiet(leaderstats, statName, timeout)
end

local function previewDebug(previewKey, ...)
	if PREVIEW_DEBUG and previewKey and tostring(previewKey):match("^Index_") then
		warn("[IndexDebug][ServerPreview]", previewKey, ...)
	end
end

local function isFiniteNumber(value)
	return typeof(value) == "number"
		and value == value
		and value > -math.huge
		and value < math.huge
end

local function sanitizeSkipBrainrot(value)
	if not isFiniteNumber(value) then
		return nil
	end

	return math.clamp(math.floor(value), 0, MAX_SKIP_BRAINROT)
end

local function sanitizePreviewString(value, maxLength)
	if typeof(value) ~= "string" then
		return nil
	end

	value = value:match("^%s*(.-)%s*$") or ""
	if value == "" or #value > maxLength then
		return nil
	end

	return value
end

local function sanitizePreviewRequest(previewKey, name, mutation)
	local safePreviewKey = sanitizePreviewString(previewKey, MAX_PREVIEW_KEY_LENGTH)
	local safeName = sanitizePreviewString(name, MAX_PREVIEW_NAME_LENGTH)
	local safeMutation = typeof(mutation) == "string" and MutationModule:NormalizeName(mutation) or "Normal"

	if not safePreviewKey or not safeName then
		return nil
	end

	return safePreviewKey, safeName, safeMutation
end

local function getPreviewPlayerFolder(player)
	local folder = PreviewCache:FindFirstChild(tostring(player.UserId))
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = tostring(player.UserId)
		folder.Parent = PreviewCache
	end

	return folder
end

local function getPreviewTemplate(previewKey, name, mutation)
	local rootFolder = ServerStorage:FindFirstChild("BrainrotModel") or RP:FindFirstChild("BrainrotModel")
	if not rootFolder then
		previewDebug(previewKey, "BrainrotModel folder missing")
		return nil
	end

	local normalFolder = rootFolder:FindFirstChild("Normal")
	if not normalFolder then
		previewDebug(previewKey, "Normal folder missing")
		return nil
	end

	local selectedFolder = nil
	for _, folderName in ipairs(MutationModule:GetLookupNames(mutation)) do
		selectedFolder = rootFolder:FindFirstChild(folderName)
		if selectedFolder then
			break
		end
	end

	selectedFolder = selectedFolder or normalFolder

	local previewTemplate = selectedFolder:FindFirstChild(name) or normalFolder:FindFirstChild(name)
	if previewTemplate then
		previewDebug(previewKey, "template found", "folder=", selectedFolder.Name, "name=", name, "mutation=", mutation)
		return previewTemplate
	end

	previewTemplate = rootFolder:FindFirstChild(name, true)
	if previewTemplate then
		previewDebug(
			previewKey,
			"template found via recursive search",
			"container=",
			previewTemplate.Parent and previewTemplate.Parent.Name or "nil"
		)
		return previewTemplate
	end

	previewDebug(previewKey, "template missing", "name=", name, "mutation=", mutation)
	return nil
end

local function createPreviewModel(player, previewKey, name, mutation)
	local safePreviewKey, safeName, safeMutation = sanitizePreviewRequest(previewKey, name, mutation)
	if not safePreviewKey then
		return false
	end

	local previewTemplate = getPreviewTemplate(safePreviewKey, safeName, safeMutation)
	if not previewTemplate then
		return false
	end

	local playerFolder = getPreviewPlayerFolder(player)
	local previewFolder = playerFolder:FindFirstChild(safePreviewKey)
	if previewFolder then
		previewFolder:Destroy()
	end

	previewFolder = Instance.new("Folder")
	previewFolder.Name = safePreviewKey
	previewFolder.Parent = playerFolder

	previewTemplate:Clone().Parent = previewFolder
	previewDebug(previewKey, "preview cloned", "player=", player.Name)
	return true
end

local function clearPreviewModel(player, previewKey)
	local safePreviewKey = sanitizePreviewString(previewKey, MAX_PREVIEW_KEY_LENGTH)
	if not safePreviewKey then
		return false
	end

	local playerFolder = PreviewCache:FindFirstChild(tostring(player.UserId))
	if not playerFolder then
		return true
	end

	local previewFolder = playerFolder:FindFirstChild(safePreviewKey)
	if previewFolder then
		previewFolder:Destroy()
	end

	return true
end

Players.PlayerRemoving:Connect(function(player)
	local playerFolder = PreviewCache:FindFirstChild(tostring(player.UserId))
	if playerFolder then
		playerFolder:Destroy()
	end
end)

function GetInfo:Init(player, ...)
	local Hall = { ... }
	local EventType = Hall[1]

	if EventType == "Data" then
		local profile = DataManager:GetProfile(player)
		local data = profile and profile.Data
		DataManager:SyncIndex(player)
		return data, "error"
	elseif EventType == "Index" then
		local List = nil
		local count = 0

		if IndexList then
			List, count = IndexList:CreateList()
		end
		return List, count
	elseif EventType == "AuraList" then
		return AuraList[Hall[2]]
	elseif EventType == "Rebirth" then
		local Rebirth = getLeaderstat(player, "Rebirth")
		return Rebirth and UpgradeList[tostring(Rebirth.Value + 1)] or nil
	elseif EventType == "RebrithLoad" then
		local Base = require(game.ServerStorage.Module.GameHandler.Base)
		local Rebirth = getLeaderstat(player, "Rebirth")
		if not Rebirth then
			return nil
		end
		local profile = DataManager:GetProfile(player)
		local data = profile and profile.Data
		local NewBase = Base.GetBase(player)

		Rebirth.Value += 1

		if data and NewBase then
		end
	elseif EventType == "Roll" then
		local profile = DataManager:GetProfile(player)
		local data = profile and profile.Data

		if data then
			return data.Settings.AutoRoll, data.Settings.FastRoll
		end
		return false, false
	elseif EventType == "PassId" then
		return PassId[Hall[2]] and PassId[Hall[2]].Id
	elseif EventType == "GetSkipBrairot" then
		local profile = DataManager:GetProfile(player)
		local data = profile and profile.Data

		if data then
			local skipBrainrot = sanitizeSkipBrainrot(data.Settings.SkipBrainrot) or 0
			data.Settings.SkipBrainrot = skipBrainrot
			return skipBrainrot
		end
	elseif EventType == "UpdateSkipBrairot" then
		local skipBrainrot = sanitizeSkipBrainrot(Hall[2])
		if skipBrainrot ~= nil then
			local profile = DataManager:GetProfile(player)
			local data = profile and profile.Data

			if data then
				data.Settings.SkipBrainrot = skipBrainrot
				print(`Skip brainrot : {tostring(data.Settings.SkipBrainrot)} !`)
				return true, skipBrainrot
			end
		end
		return false
	elseif EventType == "GetClientSettings" then
		return DataManager:GetClientSettings(player)
	elseif EventType == "UpdateClientSetting" then
		return DataManager:SetClientSetting(player, Hall[2], Hall[3])
	elseif EventType == "PreviewBrainrot" then
		return createPreviewModel(player, Hall[2], Hall[3], Hall[4])
	elseif EventType == "ClearPreviewBrainrot" then
		return clearPreviewModel(player, Hall[2])
	end
end

return GetInfo
