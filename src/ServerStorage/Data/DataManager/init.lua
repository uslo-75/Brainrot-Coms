local Players = game:GetService("Players")
local RP = game:GetService("ReplicatedStorage")
local RS = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local profileStore = require(script.ProfileStore)
local Template = require(script.Template)
local Base = require(ServerStorage.Module.GameHandler.Base)
local BrairotList = require(ServerStorage.List.BrainrotList)
local MutationModule = require(ServerStorage.Module.RollModule.Mutation)
local GameConfig = require(RP:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local PlayerSettingsConfig = require(RP:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("PlayerSettingsConfig"))

local MyService = require(RP:WaitForChild("MyService"):WaitForChild("MyService"))

local DataManager = {}
local ProfileAsset = {}
DataManager.Profiles = {}
local ServiceTable = {
	
}

local DATASTORE_VERSION = "V1"


------------------------------
-----///Data Fonction Apply//-----
------------------------------

type Currency = {
	name : string,
	value : number,
	player : Player
}

local function GetStoreName()
	return RS:IsStudio() and ("BetaTest_" .. DATASTORE_VERSION) or ("Live_" .. DATASTORE_VERSION)
end

local PlayerStore = profileStore.New(GetStoreName(), Template)
local LARGE_LEADERSTAT_TYPES = {
	Cash = "NumberValue",
}
local MAX_SKIP_BRAINROT = GameConfig.Data.MaxSkipBrainrot
local DEFAULT_MUSIC = GameConfig.Data.DefaultMusic
local MIN_MUSIC = GameConfig.Data.MusicMin
local MAX_MUSIC = GameConfig.Data.MusicMax

local function SetInstance(name, _type, value, parent)
	local instance = Instance.new(_type)
	instance.Name = name
	instance.Value = value
	instance.Parent = parent
	return instance
end

local function GetLeaderstatInstanceType(name, value)
	local forcedType = LARGE_LEADERSTAT_TYPES[name]
	if forcedType then
		return forcedType
	end

	local valueType = typeof(value)
	if valueType == "number" then
		return "IntValue"
	elseif valueType == "string" then
		return "StringValue"
	elseif valueType == "boolean" then
		return "BoolValue"
	end

	return nil
end

local function ColisionGrounpByPlayer(player)
	local character = player.Character or player.CharacterAdded:Wait()

	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Players"
		end
	end
end

local function NormalizeMutationName(mutation)
	return MutationModule:NormalizeName(mutation or "Normal")
end

local function IsFiniteNumber(value)
	return typeof(value) == "number"
		and value == value
		and value > -math.huge
		and value < math.huge
end

local function NormalizeSkipBrainrotValue(value)
	if not IsFiniteNumber(value) then
		return 0
	end

	return math.clamp(math.floor(value), 0, MAX_SKIP_BRAINROT)
end

local function RollDiscoMutation()
	local totalWeight = 0

	for name, info in pairs(MutationModule.Mutation) do
		if name ~= "Normal" then
			totalWeight += info.Chance
		end
	end

	if totalWeight <= 0 then
		return "Gold"
	end

	local roll = math.random() * totalWeight
	local current = 0

	for name, info in pairs(MutationModule.Mutation) do
		if name ~= "Normal" then
			current += info.Chance
			if roll <= current then
				return name
			end
		end
	end

	return "Gold"
end

local function ShouldForceDiscoMutation()
	return Workspace:GetAttribute("ActiveAdminAbuse") == "Disco"
end

local function ResetAuraSpinState(data)
	if not data then
		return false
	end

	if not data.AuraSpin then
		data.AuraSpin = {
			Name = "",
			Position = "",
		}
		return true
	end

	if data.AuraSpin.Name == "" and data.AuraSpin.Position == "" then
		return false
	end

	data.AuraSpin.Name = ""
	data.AuraSpin.Position = ""
	return true
end

local function ResetFuseState(data)
	if not data then
		return false
	end

	if typeof(data.Fuse) ~= "table" then
		data.Fuse = {
			Fusing = {},
			FuseEndTime = 0,
			FuseMode = "None",
		}
		return true
	end

	local changed = false

	if typeof(data.Fuse.Fusing) ~= "table" then
		data.Fuse.Fusing = {}
		changed = true
	end

	if typeof(data.Fuse.FuseEndTime) ~= "number" then
		data.Fuse.FuseEndTime = 0
		changed = true
	end

	if typeof(data.Fuse.FuseMode) ~= "string" or data.Fuse.FuseMode == "" then
		data.Fuse.FuseMode = "None"
		changed = true
	end

	return changed
end

local function NormalizeSettings(data)
	if not data then
		return false
	end

	local changed = false

	if typeof(data.Settings) ~= "table" then
		data.Settings = {}
		changed = true
	end

	local settings = data.Settings

	if typeof(settings.Music) ~= "number" then
		settings.Music = DEFAULT_MUSIC
		changed = true
	elseif settings.Music ~= math.clamp(settings.Music, MIN_MUSIC, MAX_MUSIC) then
		settings.Music = math.clamp(settings.Music, MIN_MUSIC, MAX_MUSIC)
		changed = true
	end

	if typeof(settings.SkipBrainrot) ~= "number" then
		settings.SkipBrainrot = 0
		changed = true
	else
		local normalizedSkipBrainrot = NormalizeSkipBrainrotValue(settings.SkipBrainrot)
		if settings.SkipBrainrot ~= normalizedSkipBrainrot then
			settings.SkipBrainrot = normalizedSkipBrainrot
			changed = true
		end
	end

	if typeof(settings.AutoRoll) ~= "boolean" then
		settings.AutoRoll = false
		changed = true
	end

	if typeof(settings.FastRoll) ~= "boolean" then
		settings.FastRoll = false
		changed = true
	end

	for _, settingName in ipairs(PlayerSettingsConfig.ToggleOrder) do
		local normalizedValue = PlayerSettingsConfig.GetToggleValue(settings, settingName)
		if settings[settingName] ~= normalizedValue then
			settings[settingName] = normalizedValue
			changed = true
		end
	end

	return changed
end

local function ApplyPlayerSettingsAttributes(player, data)
	if not (player and data) then
		return
	end

	NormalizeSettings(data)
	PlayerSettingsConfig.ApplyPlayerAttributes(player, data.Settings)
end

local function GetRemoteEvent()
	if ServiceTable["RemoteEvent"] then
		return ServiceTable["RemoteEvent"]
	end

	ServiceTable["RemoteEvent"] =
		MyService:LoadService("RemoteEvent")
		or MyService:GetService("RemoteEvent")
		or require(RP:WaitForChild("MyService"):WaitForChild("Service"):WaitForChild("RemoteEvent"))

	return ServiceTable["RemoteEvent"]
end

local function NotifyAuraSpinCleared(player)
	if not player then
		return
	end

	local remoteEvent = GetRemoteEvent()
	if remoteEvent then
		remoteEvent:InvokeClient("AuraSpin", player, "Empty")
		remoteEvent:InvokeClient("AuraSpin", player, "BrairotPreview", false)
	end
end

local function NotifyFuseCleared(player)
	if not player then
		return
	end

	local remoteEvent = GetRemoteEvent()
	if remoteEvent then
		remoteEvent:InvokeClient("FuseEvent", player, "Clear")
	end
end

local function EnsureIndexEntry(indexData, name, mutation)
	if not name or name == "" then
		return false
	end

	mutation = NormalizeMutationName(mutation)

	if typeof(indexData[name]) ~= "table" then
		indexData[name] = {}
	end

	if indexData[name][mutation] then
		return false
	end

	indexData[name][mutation] = true
	return true
end

local function SyncOwnedBrainrotIntoIndexData(data)
	if not data then
		return {}
	end

	if typeof(data.Index) ~= "table" then
		data.Index = {}
	end
	local indexData = data.Index
	local brainrotList = data.Base and data.Base.Brainrot

	if typeof(brainrotList) ~= "table" then
		return indexData
	end

	for _, brainrot in ipairs(brainrotList) do
		if brainrot and brainrot.Name then
			EnsureIndexEntry(indexData, brainrot.Name, brainrot.Mutation)
		end
	end

	return indexData
end

local function NormalizeBaseBrainrotData(data)
	if not data then
		return false
	end

	if typeof(data.Base) ~= "table" then
		data.Base = {}
	end

	if typeof(data.Base.Brainrot) ~= "table" then
		data.Base.Brainrot = {}
		return true
	end

	local changed = false
	local seenPositions = {}

	for index = #data.Base.Brainrot, 1, -1 do
		local brainrot = data.Base.Brainrot[index]

		if typeof(brainrot) ~= "table" or not brainrot.Name then
			table.remove(data.Base.Brainrot, index)
			changed = true
			continue
		end

		local position = tostring(brainrot.Position or "")
		if position == "" then
			table.remove(data.Base.Brainrot, index)
			changed = true
			continue
		end

		brainrot.Position = position
		brainrot.Mutation = NormalizeMutationName(brainrot.Mutation)

		if seenPositions[position] then
			table.remove(data.Base.Brainrot, index)
			changed = true
		else
			seenPositions[position] = true
		end
	end

	return changed
end

local function ClearDependentBrainrotState(player, data, position)
	if not data then
		return
	end

	local positionString = tostring(position)
	local auraSpinCleared = false

	if data.AuraSpin and tostring(data.AuraSpin.Position) == positionString then
		data.AuraSpin.Name = ""
		data.AuraSpin.Position = ""
		auraSpinCleared = true
	end

	if data.Fuse and typeof(data.Fuse.Fusing) == "table" then
		local removedFromFuse = false

		for index = #data.Fuse.Fusing, 1, -1 do
			local fusingItem = data.Fuse.Fusing[index]
			if fusingItem and tostring(fusingItem.Position) == positionString then
				table.remove(data.Fuse.Fusing, index)
				removedFromFuse = true
			end
		end

		if removedFromFuse and (data.Fuse.FuseMode ~= "None" or (data.Fuse.FuseEndTime or 0) > 0) then
			data.Fuse.FuseMode = "None"
			data.Fuse.FuseEndTime = 0
			NotifyFuseCleared(player)
		end
	end

	if auraSpinCleared then
		NotifyAuraSpinCleared(player)
	end
end

local function SyncDependentBrainrotPositions(data, position1, position2)
	if not data then
		return
	end

	local position1String = tostring(position1)
	local position2String = tostring(position2)

	if data.AuraSpin then
		local auraPosition = tostring(data.AuraSpin.Position)
		if auraPosition == position1String then
			data.AuraSpin.Position = position2String
		elseif auraPosition == position2String then
			data.AuraSpin.Position = position1String
		end
	end

	if data.Fuse and typeof(data.Fuse.Fusing) == "table" then
		for _, fusingItem in ipairs(data.Fuse.Fusing) do
			if fusingItem then
				local fusePosition = tostring(fusingItem.Position)
				if fusePosition == position1String then
					fusingItem.Position = position2String
				elseif fusePosition == position2String then
					fusingItem.Position = position1String
				end
			end
		end
	end
end

function UpdateValue(player : Instance, data)
	local leaderstats = player:WaitForChild("leaderstats")

	for _, v in pairs(leaderstats:GetChildren()) do
		if data.Leaderstats[v.Name] then
			data.Leaderstats[v.Name] = v.Value
		else
			if v.Name == "Rebirth" then
				data.Base.rebrith = v.Value
			end
		end
	end
end

------------------------------
-----///PlayerAdded Apply//-----
------------------------------

local function PlayerAdded(player : Player)
	PlayerSettingsConfig.SetLoaded(player, false)

	local profile = PlayerStore:StartSessionAsync("Players_"..player.UserId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile ~= nil then
		profile:AddUserId(player.UserId)
		profile:Reconcile()

		profile.OnSessionEnd:Connect(function()
			DataManager.Profiles[player] = nil
			player:Kick("Data error occuped, Please rejoin.")
		end)

		if player.Parent == Players then
			DataManager.Profiles[player] = profile
			ProfileAsset[player] = profile
			DataManager:Init(player, profile)
		end
		
		local NewBase = Base.new(player, DataManager.Profiles[player], DataManager)

	else
		player:Kick("Data no select please rejoin")
	end

end

------------------------------
---------// Init //-----------
------------------------------

function DataManager:Init(player, profile)
	NormalizeBaseBrainrotData(profile and profile.Data)
	SyncOwnedBrainrotIntoIndexData(profile and profile.Data)
	ResetAuraSpinState(profile and profile.Data)
	ResetFuseState(profile and profile.Data)
	NormalizeSettings(profile and profile.Data)

	local CData = Instance.new("Folder", player)
	CData.Name = "CData"


	local DataFolder = Instance.new("Folder", CData)
	DataFolder.Name = "Data"

	local leaderstats = Instance.new("Folder", player)
	leaderstats.Name = "leaderstats"
	
	local StatsFolder = Instance.new("Folder", player)
	StatsFolder.Name = "Stats"

	for name, value in pairs(profile.Data.Leaderstats) do
		local intType = GetLeaderstatInstanceType(name, value)

		if intType then SetInstance(name, intType, value, leaderstats) end
	end
	
	SetInstance("Rebirth", "IntValue", profile.Data.Base.rebrith or 0, leaderstats)
	SetInstance("LuckBuff", "IntValue", 0, StatsFolder)
	SetInstance("CashBuff", "IntValue", 0, StatsFolder)
	ApplyPlayerSettingsAttributes(player, profile and profile.Data)

	ColisionGrounpByPlayer(player)
	
	if profile.Data.AuraSpin.Name ~= "" then
		local name = profile.Data.AuraSpin.Name
		local Position = profile.Data.AuraSpin.Position
		local brainrotData = DataManager.GetBrainrot(player, Position)
		if brainrotData then
			local Mutation = brainrotData.Mutation
			
			task.spawn(function()
				local remoteEvent = GetRemoteEvent()
				if remoteEvent then
					remoteEvent:InvokeClient(
						"AuraSpin",
						player,
						"BrairotPreview",
						true,
						Mutation,
						name,
						brainrotData.Slots or {}
					)
				end
			end)
			
		end
	end

end

function DataManager:HassBrairot(player, List)
	local profile = DataManager.Profiles[player]
	local data = profile and profile.Data
	if not data or type(List) ~= "table" then return false, {} end

	local BrainrotData = data.Base.Brainrot
	local owned = {}
	local result = {}
	local count = 0

	for _, brainrot in ipairs(BrainrotData) do
		owned[brainrot.Name] = true
	end

	for _, v in ipairs(List) do
		if owned[v] then
			result[v] = true
			count+= 1
		end
	end
	

	return count == #List, result
end

function DataManager:GetProfile(player)
	return DataManager.Profiles[player] or ProfileAsset[player]
end

function DataManager:GetClientSettings(player)
	local profile = DataManager.Profiles[player] or ProfileAsset[player]
	local data = profile and profile.Data
	if not data then
		return nil
	end

	NormalizeSettings(data)
	return PlayerSettingsConfig.GetToggleSettings(data.Settings)
end

function DataManager:SetClientSetting(player, settingName, value)
	local definition = PlayerSettingsConfig.GetDefinition(settingName)
	if not definition or typeof(value) ~= "boolean" then
		return false, nil
	end

	local profile = DataManager.Profiles[player] or ProfileAsset[player]
	local data = profile and profile.Data
	if not data then
		return false, nil
	end

	NormalizeSettings(data)
	data.Settings[settingName] = value
	ApplyPlayerSettingsAttributes(player, data)

	return true, value
end


function DataManager.AddIndex(player, name, mutation)
	local profile = DataManager.Profiles[player]
	if not profile then return false end

	local data = profile.Data
	if not data then return false end

	local indexData = SyncOwnedBrainrotIntoIndexData(data)
	return EnsureIndexEntry(indexData, name, mutation)
end

function DataManager:SyncIndex(player)
	local profile = DataManager.Profiles[player] or ProfileAsset[player]
	local data = profile and profile.Data
	return SyncOwnedBrainrotIntoIndexData(data)
end

---------------------------------
-----///Brainrot Fonction//-----
---------------------------------

function DataManager.GetBrainrot(player, Position)
	local profile = DataManager.Profiles[player]
	if not profile then warn("pas de profile") return nil end

	local data = profile.Data
	local BaseData = data.Base
	local BrainrotData = BaseData.Brainrot


	for _, brainrot in pairs(BrainrotData) do
		if brainrot.Position == Position or brainrot.Position == tostring(Position) then
			return brainrot
		end
	end
	return nil
end

function DataManager.RemoveBrainrot(player, position)
	local profile = DataManager.Profiles[player]
	if not profile then return false end

	local data = profile.Data
	local BaseData = data.Base
	local BrainrotData = BaseData.Brainrot

	for index, brainrot in ipairs(BrainrotData) do
		if tostring(brainrot.Position) == tostring(position) then
			table.remove(BrainrotData, index) 
			ClearDependentBrainrotState(player, data, position)
			return true 
		end
	end
	return false
end

function DataManager:ChangePosition(player, position1, position2)
	local info1 = DataManager.GetBrainrot(player, position1)
	local info2 = DataManager.GetBrainrot(player, position2)
	local profile = DataManager.Profiles[player]
	local data = profile and profile.Data
	

	if not info1 and not info2 then
		warn("Aucun item trouvÃƒÂ© aux positions", position1, position2)
		return
	end

	if info1 and info2 then
		info1.Position, info2.Position = position2, position1
		SyncDependentBrainrotPositions(data, position1, position2)
		return info1, info2
	end
	if info1 then
		info1.Position = position2
		SyncDependentBrainrotPositions(data, position1, position2)
	elseif info2 then
		info2.Position = position1
		SyncDependentBrainrotPositions(data, position1, position2)
	end
	
	return info1, info2
end

function DataManager:ClearAuraSpin(player)
	local profile = DataManager.Profiles[player] or ProfileAsset[player]
	local data = profile and profile.Data
	if not data or not data.AuraSpin then
		return false
	end

	if data.AuraSpin.Name == "" and data.AuraSpin.Position == "" then
		return false
	end

	data.AuraSpin.Name = ""
	data.AuraSpin.Position = ""
	NotifyAuraSpinCleared(player)

	return true
end

function DataManager.AddBrainrot(player, ...)
	local halls = {...}
	local profile = DataManager.Profiles[player]
	if not profile then return end

	local data = profile.Data
	if not data then return nil end
	
	if BrairotList[halls[1]] == nil then
		return false
	end

	local mutation = NormalizeMutationName(halls[2])
	if not MutationModule.Mutation[mutation] then
		mutation = "Normal"
	end

	if ShouldForceDiscoMutation() and mutation == "Normal" then
		mutation = RollDiscoMutation()
	end

	local TableRecup = {
		Name = halls[1],
		Mutation = mutation,
		Slots = halls[3],
		Position = tostring(halls[4] or "1"),
		HorsLineCash = 0,
	}

	for index = #data.Base.Brainrot, 1, -1 do
		local brainrot = data.Base.Brainrot[index]
		if brainrot and tostring(brainrot.Position) == TableRecup.Position then
			table.remove(data.Base.Brainrot, index)
		end
	end

	table.insert(data.Base.Brainrot, TableRecup)
	EnsureIndexEntry(SyncOwnedBrainrotIntoIndexData(data), TableRecup.Name, TableRecup.Mutation)


	return TableRecup
end

function DataManager.AddCurrency(name, value, player)
	if not player then
		warn("DataManager.AddCurrency called without player")
		return false
	end
	
	local profile = DataManager.Profiles[player] or ProfileAsset[player]
	local leaderstats = player:WaitForChild("leaderstats")
	local currIns = leaderstats and leaderstats:FindFirstChild(name)
	
	if currIns then
		currIns.Value += value
		if profile and profile.Data and profile.Data.Leaderstats and typeof(profile.Data.Leaderstats[name]) == "number" then
			profile.Data.Leaderstats[name] = currIns.Value
		end
		return true
	end
	return false
end

function DataManager.CashHorLine(player, position, value)
	local info = DataManager.GetBrainrot(player, position)

	if info then
		info.HorsLineCash = value or 0
	end
end


---------------------------------
-----///Other Fonction//-----
---------------------------------

Players.PlayerAdded:Connect(PlayerAdded)

for _, player in pairs(Players:GetPlayers()) do
	task.spawn(PlayerAdded, player)
	Base:Removing(player)
end

Players.PlayerRemoving:Connect(function(player)
	local profile = DataManager.Profiles[player]
	if not profile then return end
	ResetAuraSpinState(profile.Data)
	Base:Removing(player)
	UpdateValue(player, profile.Data)

	profile:EndSession()
	DataManager.Profiles[player] = nil
	
end)

return DataManager
