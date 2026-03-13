local RP = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local myServices = require(RP:WaitForChild("MyService"):WaitForChild("MyService"))

local DataManager = require(ServerStorage.Data.DataManager)
local BrainrotList = require(ServerStorage.List.BrainrotList)
local BrairotSelect = require(ServerStorage.Module.BrainrotSelect)
local BaseModule = require(ServerStorage.Module.GameHandler.Base)
local MessageModule = require(RP.Module.MessageModule)
local MutationModule = require(ServerStorage.Module.RollModule.Mutation)

local Machine = {}
local ServiceTable = {}
local Last = {}
local machineInstance = nil

Machine.Settings = {
	MaxSlots = 4,
	PreviewResults = 6,
	DefaultFuseDuration = 60 * 30,
	FuseDurationByRarity = {
		[1] = 60 * 15,
		[2] = 60 * 15,
		[3] = 60 * 15,
		[4] = 60 * 30,
		[5] = 60 * 30,
		[6] = 60 * 30,
		[7] = 60 * 90,
		[8] = 60 * 90,
	},
	MinimumFuseCost = 500,
	BaseFuseCostFactor = 0.12,
	FuseCostFactorStep = 0.02,
	RarityIndex = {
		Commun = 1,
		Rare = 2,
		Epic = 3,
		Legendaire = 4,
		Mythique = 5,
		["Brainrot God"] = 6,
		Secret = 7,
		Prototype = 8,
	}
}

local function Count(list)
	local count = 0
	for _ in pairs(list) do
		count += 1
	end
	return count
end

local function GetMaxRarityIndex(rarityIndex)
	local maxIndex = 1

	for _, index in pairs(rarityIndex or {}) do
		if index > maxIndex then
			maxIndex = index
		end
	end

	return maxIndex
end

local MAX_RARITY_INDEX = GetMaxRarityIndex(Machine.Settings.RarityIndex)

local function NormalizeResultChances(results)
	if not results or #results == 0 then
		return
	end

	local totalWeight = 0

	for _, item in ipairs(results) do
		item.Weight = math.max(0, tonumber(item.Weight or item.Chance) or 0)
		totalWeight += item.Weight
	end

	if totalWeight <= 0 then
		local baseChance = math.floor(100 / #results)
		local remainder = 100 - (baseChance * #results)

		for index, item in ipairs(results) do
			item.Chance = baseChance + (index <= remainder and 1 or 0)
		end

		return
	end

	local remainderPool = 100
	local fractions = {}

	for index, item in ipairs(results) do
		local exactChance = (item.Weight / totalWeight) * 100
		local flooredChance = math.floor(exactChance)

		item.Chance = flooredChance
		remainderPool -= flooredChance

		table.insert(fractions, {
			Index = index,
			Fraction = exactChance - flooredChance,
			Weight = item.Weight,
		})
	end

	table.sort(fractions, function(a, b)
		if math.abs(a.Fraction - b.Fraction) < 0.0001 then
			if a.Weight == b.Weight then
				return a.Index < b.Index
			end

			return a.Weight > b.Weight
		end

		return a.Fraction > b.Fraction
	end)

	for step = 1, remainderPool do
		local target = fractions[((step - 1) % #fractions) + 1]
		results[target.Index].Chance += 1
	end
end

local function SortRewardCandidates(a, b)
	if a.DistanceToTarget == b.DistanceToTarget then
		if a.CashDistance == b.CashDistance then
			if a.Weight == b.Weight then
				if a.Index == b.Index then
					return a.Name < b.Name
				end

				return a.Index < b.Index
			end

			return a.Weight > b.Weight
		end

		return a.CashDistance < b.CashDistance
	end

	return a.DistanceToTarget < b.DistanceToTarget
end

local function CreateRewardCandidate(machine, name, info, targetIndex, targetCash, averageIndex)
	local brainrotInfo = BrainrotList[name]
	if not brainrotInfo then
		return nil
	end

	local weight = tonumber(info.chance or info.Chance or info) or 0
	if weight <= 0 then
		return nil
	end

	local minCash = info.CashMin
	if minCash and targetCash < minCash then
		return nil
	end

	local minAverageIndex = info.MinAverageIndex
	if minAverageIndex and averageIndex < minAverageIndex then
		return nil
	end

	local rarityIndex = machine.Settings.RarityIndex[brainrotInfo.Rarity] or 1

	return {
		Name = name,
		Rarity = brainrotInfo.Rarity,
		Chance = weight,
		Weight = weight,
		Cash = brainrotInfo.CashPerSeconde,
		Index = rarityIndex,
		CashDistance = math.abs(brainrotInfo.CashPerSeconde - targetCash),
		DistanceToTarget = math.abs(rarityIndex - targetIndex),
	}
end

local function GetFusionModel()
	local interactFolder = Workspace:WaitForChild("InteractFolder")
	return interactFolder:WaitForChild("Fusion")
end

local function ClearSlot(slotModel)
	if not slotModel then
		return
	end

	slotModel:SetAttribute("Enter", false)
	slotModel:SetAttribute("CurrentCash", 0)
	slotModel:SetAttribute("CashPerSeconde", nil)

	local claimPart = slotModel:FindFirstChild("ClaimCash")
	if claimPart then
		local cashLabel = claimPart:FindFirstChild("CashLabel")
		if cashLabel then
			cashLabel:Destroy()
		end
	end
end

local function GetDominantRarityIndex(rarityCounts, fallbackIndex)
	local dominantIndex = fallbackIndex or 1
	local dominantCount = 0

	for rarityIndex, count in pairs(rarityCounts or {}) do
		if count > dominantCount or (count == dominantCount and rarityIndex > dominantIndex) then
			dominantIndex = rarityIndex
			dominantCount = count
		end
	end

	return dominantIndex
end

local function BuildMutationPercents(mutationCounts)
	local mutationPercents = { Normal = 100 }
	local hasMutation = false

	for mutation, count in pairs(mutationCounts or {}) do
		if count > 0 and mutation ~= "Normal" then
			hasMutation = true
			local chance = math.min(20, 10 + ((count - 1) * 5))
			mutationPercents[mutation] = chance
			mutationPercents.Normal -= chance
		end
	end

	if not hasMutation then
		mutationPercents.Normal = 100
	else
		mutationPercents.Normal = math.max(0, mutationPercents.Normal)
	end

	return mutationPercents
end

local function GetFuseDuration(machine, highestIndex)
	return machine.Settings.FuseDurationByRarity[highestIndex] or machine.Settings.DefaultFuseDuration
end

local function GetFuseCost(machine, totalPrice, highestIndex)
	local factor = machine.Settings.BaseFuseCostFactor + (math.max(0, highestIndex - 1) * machine.Settings.FuseCostFactorStep)
	return math.max(machine.Settings.MinimumFuseCost, math.floor((totalPrice or 0) * factor))
end

local function BuildPreviewSummary(machine, currentCount, totalPrice, highestIndex, resultCount)
	return {
		CurrentCount = currentCount,
		Remaining = math.max(0, machine.Settings.MaxSlots - currentCount),
		ResultCount = resultCount or 0,
		Cost = GetFuseCost(machine, totalPrice, highestIndex),
		Duration = GetFuseDuration(machine, highestIndex),
		HighestRarityIndex = highestIndex,
		CanFuse = currentCount >= machine.Settings.MaxSlots,
	}
end

local function IsFuseRunning(fuseData)
	return fuseData and fuseData.FuseMode ~= "None" and (fuseData.FuseEndTime or 0) > os.time()
end

local function RollMutation(mutationPercents)
	local total = 0

	for _, chance in pairs(mutationPercents or {}) do
		total += chance
	end

	if total <= 0 then
		return "Normal"
	end

	local roll = math.random() * total
	local current = 0

	for mutation, chance in pairs(mutationPercents) do
		current += chance
		if roll <= current then
			return mutation
		end
	end

	return "Normal"
end

local function ResetFuseData(data)
	if not (data and data.Fuse) then
		return false
	end

	local currentList = data.Fuse.Fusing
	local hadItems = typeof(currentList) == "table" and #currentList > 0
	local hadTimer = data.Fuse.FuseMode ~= "None" or (data.Fuse.FuseEndTime or 0) > 0

	data.Fuse.Fusing = {}
	data.Fuse.FuseMode = "None"
	data.Fuse.FuseEndTime = 0

	return hadItems or hadTimer
end

function Machine.new(model)
	local self = setmetatable({}, { __index = Machine })
	self.Model = model
	self.CollectZone = model:FindFirstChild("CollectZone")
	self.Hitbox = self.CollectZone and self.CollectZone:FindFirstChild("Hitbox")
	self.FuseMachine = model:FindFirstChild("FuseMachine")
	self.Hits = {}
	self.List = require(script.List.Fusion)
	self.Initialized = false
	return self
end

function Machine:Return()
	return machineInstance
end

function Machine:GetOrCreate()
	if machineInstance then
		return machineInstance
	end

	machineInstance = Machine.new(GetFusionModel())
	return machineInstance
end

function Machine:ChangeFuseMode(player, data)
	if data and player and data.Fuse and data.Fuse.Fusing then
		if #data.Fuse.Fusing == self.Settings.MaxSlots then
			data.Fuse.FuseMode = "InFuse"
		end
	end
end

function Machine:TryAssignCarriedBrainrot(player, char)
	if not (player and char) then
		return false
	end

	local profile = DataManager:GetProfile(player)
	local data = profile and profile.Data
	if not (data and data.Fuse and typeof(data.Fuse.Fusing) == "table") then
		return false
	end

	if #data.Fuse.Fusing >= self.Settings.MaxSlots then
		MessageModule:SendMessage(player, "Fuse machine full !", 1.5, Color3.new(1, 0, 0))
		return false
	end

	local brairotGrab = BrairotSelect:GetGrabModel(char)
	local brairotPlace = BrairotSelect:GetPlace(char)
	if not (brairotGrab and brairotPlace) then
		return false
	end

	if char:GetAttribute("Type") ~= "InPlace" then
		return false
	end

	if brairotGrab:GetAttribute("Owner") ~= player.Name then
		return false
	end

	local position = tostring(brairotGrab:GetAttribute("Position") or "")
	local isValidMutation, normalizedMutation = MutationModule:IsMutation(brairotGrab:GetAttribute("Mutation") or "Normal")
	local mutation = isValidMutation and normalizedMutation or "Normal"
	local name = brairotGrab.Name

	if position == "" or not name then
		return false
	end

	for _, item in ipairs(data.Fuse.Fusing) do
		if item and tostring(item.Position) == position then
			return false
		end
	end

	table.insert(data.Fuse.Fusing, {
		Name = name,
		Position = position,
		Mutation = mutation,
	})

	brairotPlace:SetAttribute("Type", "InMachine")
	brairotPlace:SetAttribute("Mode", "Fusion")
	brairotPlace:SetAttribute("InPlace", false)

	BrairotSelect:UnGrab(char)
	BrairotSelect:ClearGrab(char)
	BrairotSelect:RemovePlace(char)
	BrairotSelect:RemoveInfo(char)

	char:SetAttribute("InPlace", false)
	char:SetAttribute("Type", "None")

	self:Update(data, player)
	self:SyncFuseState(player)

	return true
end

function Machine:Update(data, player)
	local currentList = data and data.Fuse and data.Fuse.Fusing
	if currentList and typeof(currentList) ~= "table" then
		warn(currentList)
		return {}, {}, {}
	end

	currentList = currentList or {}
	local emptyPreview = BuildPreviewSummary(self, 0, 0, 1, 0)

	if not currentList or #currentList == 0 then
		if player and ServiceTable.RemoteEvent then
			ServiceTable.RemoteEvent:InvokeClient("FuseEvent", player, "Update", data, {}, { Normal = 100 }, emptyPreview)
		end

		return {}, { Normal = 100 }, emptyPreview
	end

	local maxResults = math.min(Count(self.List), self.Settings.PreviewResults)
	if maxResults <= 0 then
		return {}, {}, emptyPreview
	end

	local totalIndex = 0
	local totalCash = 0
	local totalPrice = 0
	local highestIndex = 1
	local rarityCounts = {}
	local mutationCounts = {}

	for _, brainrot in pairs(currentList) do
		local brainrotInfo = BrainrotList[brainrot.Name]
		if brainrotInfo then
			local rarityIndex = self.Settings.RarityIndex[brainrotInfo.Rarity] or 0
			totalIndex += rarityIndex
			totalCash += brainrotInfo.CashPerSeconde
			totalPrice += brainrotInfo.Price or 0
			highestIndex = math.max(highestIndex, rarityIndex)
			rarityCounts[rarityIndex] = (rarityCounts[rarityIndex] or 0) + 1
		end

		local isValidMutation, normalizedMutation = MutationModule:IsMutation(brainrot.Mutation or "Normal")
		brainrot.Mutation = isValidMutation and normalizedMutation or "Normal"
		if isValidMutation and normalizedMutation ~= "Normal" then
			mutationCounts[normalizedMutation] = (mutationCounts[normalizedMutation] or 0) + 1
		end
	end

	local mutationPercents = BuildMutationPercents(mutationCounts)

	local currentCount = #currentList
	if currentCount == 0 then
		currentCount = 1
	end

	local averageIndex = totalIndex / currentCount
	local averageCash = totalCash / currentCount
	local dominantIndex = GetDominantRarityIndex(rarityCounts, highestIndex)
	local completionRatio = math.clamp(
		(currentCount - 1) / math.max(1, self.Settings.MaxSlots - 1),
		0,
		1
	)
	local blendedIndex = (dominantIndex * 0.7) + (averageIndex * 0.3)
	if highestIndex > dominantIndex then
		blendedIndex += math.min(0.35, (highestIndex - dominantIndex) * 0.15)
	end

	local targetIndex = math.clamp(math.floor(blendedIndex + 0.15 + completionRatio), 1, MAX_RARITY_INDEX)
	local minimumIndex = math.max(2, targetIndex - 1)
	local ceilingIndex = math.min(MAX_RARITY_INDEX, targetIndex + 1)
	local targetCash = averageCash * (1.15 + (completionRatio * 0.45))

	local available = {}
	local fallback = {}

	for name, info in pairs(self.List) do
		local candidate = CreateRewardCandidate(self, name, info, targetIndex, targetCash, averageIndex)
		if candidate then
			table.insert(fallback, candidate)

			if candidate.Index >= minimumIndex and candidate.Index <= ceilingIndex then
				table.insert(available, candidate)
			end
		end
	end

	table.sort(available, SortRewardCandidates)
	table.sort(fallback, SortRewardCandidates)

	local final = {}
	local selected = {}

	local function appendCandidates(list)
		for _, item in ipairs(list) do
			if #final >= maxResults then
				break
			end

			if not selected[item.Name] then
				selected[item.Name] = true
				table.insert(final, item)
			end
		end
	end

	appendCandidates(available)
	if #final < maxResults then
		appendCandidates(fallback)
	end

	NormalizeResultChances(final)
	table.sort(final, function(a, b)
		if a.Chance == b.Chance then
			if a.Index == b.Index then
				return a.Name < b.Name
			end

			return a.Index < b.Index
		end

		return a.Chance > b.Chance
	end)

	for _, item in ipairs(final) do
		item.Weight = nil
		item.DistanceToTarget = nil
	end

	local preview = BuildPreviewSummary(self, currentCount, totalPrice, highestIndex, #final)

	if player and ServiceTable.RemoteEvent then
		ServiceTable.RemoteEvent:InvokeClient("FuseEvent", player, "Update", data, final, mutationPercents, preview)
	end

	return final, mutationPercents, preview
end

function Machine:Triggered()
	local promptModel = self.FuseMachine and self.FuseMachine:FindFirstChild("Prompt")
	local specialPrompt = promptModel and promptModel:FindFirstChild("Special")
	if not specialPrompt then
		return
	end

	specialPrompt.Triggered:Connect(function(player)
		if Last[player] == nil then
			Last[player] = 0
		end

		local profile = DataManager:GetProfile(player)
		local data = profile and profile.Data
		if not data or not data.Fuse then
			return
		end

		local char = player.Character or player.CharacterAdded:Wait()
		self:TryAssignCarriedBrainrot(player, char)

		Last[player] = #data.Fuse.Fusing
		self:Update(data, player)

		self:SyncFuseState(player)
	end)
end

function Machine:Touched()
	if not self.Hitbox then
		return
	end

	self.Hitbox.Touched:Connect(function(hit)
		local char = hit and hit.Parent
		if not (char and char:FindFirstChildOfClass("Humanoid")) then
			return
		end

		if self.Hits[char] then
			return
		end

		self.Hits[char] = true

		local BrairotGrab = BrairotSelect:GetGrabModel(char)
		local BrairotPlace = BrairotSelect:GetPlace(char)
		local player = Players:GetPlayerFromCharacter(char)

		if player and BrairotGrab and BrairotPlace then
			self:TryAssignCarriedBrainrot(player, char)
		end

		task.delay(1, function()
			self.Hits[char] = nil
		end)
	end)
end

function Machine:GetFuseTime(player)
	local profile = DataManager:GetProfile(player)
	if not profile then
		return "No profile"
	end

	local data = profile.Data
	local fuseData = data and data.Fuse
	if not fuseData then
		return "Machine"
	end

	if fuseData.FuseMode == "None" then
		return "Machine"
	end

	local fuseEnd = fuseData.FuseEndTime or 0
	if fuseEnd <= os.time() then
		return "Ready"
	end

	local remaining = fuseEnd - os.time()
	local hours = math.floor(remaining / 3600)
	local minutes = math.floor((remaining % 3600) / 60)
	local seconds = remaining % 60

	return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

function Machine:SyncFuseState(player)
	local profile = DataManager:GetProfile(player)
	if not profile or not ServiceTable.RemoteEvent then
		return
	end

	local data = profile.Data
	if not (data and data.Fuse and data.Fuse.Fusing) then
		return
	end

	if #data.Fuse.Fusing ~= self.Settings.MaxSlots then
		ServiceTable.RemoteEvent:InvokeClient("FuseEvent", player, "Clear")
		return
	end

	if data.Fuse.FuseMode == "None" then
		ServiceTable.RemoteEvent:InvokeClient("FuseEvent", player, "Clear")
		return
	end

	local now = os.time()
	local fuseEnd = data.Fuse.FuseEndTime or 0

	if data.Fuse.FuseMode ~= "None" and fuseEnd > now then
		ServiceTable.RemoteEvent:InvokeClient("FuseEvent", player, "Running", fuseEnd)
	else
		ServiceTable.RemoteEvent:InvokeClient("FuseEvent", player, "Ready")
	end
end

function Machine:SkipFuseTime(player)
	return self:SetFuseRemainingTime(player, 0)
end

function Machine:RemoveAllBrainrot(player, fusingData)
	local newBase = BaseModule.GetBase(player)
	if not (newBase and newBase.StockBrainrot) then
		return
	end

	local itemsToRemove = table.clone(fusingData)
	for _, item in ipairs(itemsToRemove) do
		local slotModel = newBase.StockBrainrot:FindFirstChild(item.Position)
		local brairotModel = slotModel and (slotModel:FindFirstChild(item.Name) or slotModel:FindFirstChildOfClass("Model"))

		if brairotModel then
			brairotModel:Destroy()
		end

		ClearSlot(slotModel)
		DataManager.RemoveBrainrot(player, item.Position)
	end
end

function Machine:RefreshBaseAndUi(player)
	local profile = DataManager:GetProfile(player)
	local data = profile and profile.Data
	local newBase = BaseModule.GetBase(player)

	if newBase then
		newBase:RefreshExistingBrainrots()
	end

	if data then
		Last[player] = data.Fuse and #data.Fuse.Fusing or 0
		self:Update(data, player)
		self:SyncFuseState(player)
	end
end

function Machine:ReturnSlot(player, fuseIndex)
	local profile = DataManager:GetProfile(player)
	if not profile then
		return false, "No profile"
	end

	local data = profile.Data
	if not (data and data.Fuse and typeof(data.Fuse.Fusing) == "table") then
		return false, "Aucun brainrot dans la machine"
	end

	local index = tonumber(fuseIndex)
	if not index or index < 1 or index % 1 ~= 0 then
		return false, "Slot de fusion invalide"
	end

	if data.Fuse.FuseMode ~= "None" then
		return false, "Annule la fusion avant de retirer un brainrot"
	end

	local item = data.Fuse.Fusing[index]
	if not item then
		return false, "Aucun brainrot dans ce slot"
	end

	table.remove(data.Fuse.Fusing, index)
	data.Fuse.FuseMode = "None"
	data.Fuse.FuseEndTime = 0

	self:RefreshBaseAndUi(player)

	return true, `{item.Name or "Brainrot"} est retourne dans ta base`
end

function Machine:ReturnAll(player)
	local profile = DataManager:GetProfile(player)
	if not profile then
		return false, "No profile"
	end

	local data = profile.Data
	if not (data and data.Fuse) then
		return false, "Aucun brainrot dans la machine"
	end

	local count = typeof(data.Fuse.Fusing) == "table" and #data.Fuse.Fusing or 0
	if not ResetFuseData(data) then
		return false, "Aucun brainrot dans la machine"
	end

	self:RefreshBaseAndUi(player)

	return true, count > 0 and `Les {count} brainrots sont retournes dans ta base`
		or "La fuse machine a ete reinitialisee"
end

function Machine:CancelFuse(player)
	local profile = DataManager:GetProfile(player)
	if not profile then
		return false, "No profile"
	end

	local data = profile.Data
	if not (data and data.Fuse and typeof(data.Fuse.Fusing) == "table") then
		return false, "Aucune fusion en cours"
	end

	if #data.Fuse.Fusing ~= self.Settings.MaxSlots or not IsFuseRunning(data.Fuse) then
		return false, "Aucune fusion en cours"
	end

	data.Fuse.FuseMode = "None"
	data.Fuse.FuseEndTime = 0
	self:RefreshBaseAndUi(player)

	return true, "Fusion annulee. Les brainrots restent dans la machine et le cout n'est pas rembourse."
end

function Machine:SetFuseRemainingTime(player, remainingSeconds)
	local profile = DataManager:GetProfile(player)
	if not profile then
		return false, "No profile"
	end

	local data = profile.Data
	if not (data and data.Fuse and typeof(data.Fuse.Fusing) == "table") then
		return false, "Aucune fusion en cours"
	end

	if #data.Fuse.Fusing ~= self.Settings.MaxSlots or data.Fuse.FuseMode == "None" then
		return false, "Aucune fusion en cours"
	end

	local currentEnd = data.Fuse.FuseEndTime or 0
	if currentEnd <= os.time() then
		return false, "La fusion est deja terminee."
	end

	local clampedSeconds = math.max(0, math.floor(tonumber(remainingSeconds) or 0))
	if clampedSeconds == 0 then
		data.Fuse.FuseEndTime = os.time() - 1
	else
		data.Fuse.FuseEndTime = os.time() + clampedSeconds
	end

	self:RefreshBaseAndUi(player)

	if clampedSeconds == 0 then
		return true, "La fusion est maintenant terminee."
	end

	return true, `Le temps restant de la fusion est maintenant {clampedSeconds} seconde(s).`
end

function Machine:FuseMode(player, fusingData)
	local newBase = BaseModule.GetBase(player)
	if not (newBase and newBase.StockBrainrot) then
		return
	end

	for _, item in ipairs(fusingData) do
		local slotModel = newBase.StockBrainrot:FindFirstChild(item.Position)
		local brairotModel = slotModel and (slotModel:FindFirstChild(item.Name) or slotModel:FindFirstChildOfClass("Model"))

		if brairotModel then
			brairotModel:SetAttribute("Type", "InMachine")
			brairotModel:SetAttribute("Mode", "Fusing")
		end
	end
end

function Machine:StartFuse(player)
	local profile = DataManager:GetProfile(player)
	if not profile then
		return false
	end

	local data = profile.Data
	if not (data and data.Fuse and data.Fuse.Fusing) then
		return false, "Pas assez de brainrot pour fuse !"
	end

	if #data.Fuse.Fusing ~= self.Settings.MaxSlots then
		return false, "Pas assez de brainrot pour fuse !"
	end

	if data.Fuse.FuseMode ~= "None" and (data.Fuse.FuseEndTime or 0) > os.time() then
		return false, "Une fusion est deja en cours"
	end

	local _, _, preview = self:Update(data)
	local fuseCost = preview and preview.Cost or self.Settings.MinimumFuseCost
	local fuseDuration = preview and preview.Duration or self.Settings.DefaultFuseDuration
	local cashStat = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Cash")

	if not cashStat then
		return false, "Cash introuvable"
	end

	if cashStat.Value < fuseCost then
		return false, "Pas assez de cash pour fuse (" .. tostring(fuseCost) .. " $)"
	end

	cashStat.Value -= fuseCost
	data.Fuse.FuseEndTime = os.time() + fuseDuration
	data.Fuse.FuseMode = "InFuse"
	self:FuseMode(player, data.Fuse.Fusing)
	self:SyncFuseState(player)

	return true, "Fusion lancee pour " .. tostring(fuseCost) .. " $"
end

function Machine:Fuse(player)
	local profile = DataManager:GetProfile(player)
	if not profile then
		return nil, "No profile"
	end

	local data = profile.Data
	if not (data and data.Fuse and data.Fuse.Fusing) or #data.Fuse.Fusing < self.Settings.MaxSlots then
		return nil, "Pas d'items requis dans la machine"
	end

	if (data.Fuse.FuseEndTime or 0) > os.time() then
		return nil, "Fuse en cours, temps restant : " .. self:GetFuseTime(player)
	end

	local results, mutationPercents = self:Update(data)
	if not results or #results == 0 then
		return nil, "Aucun resultat disponible"
	end

	local roll = math.random() * 100
	local cumulative = 0
	local resultItem = nil

	for _, item in ipairs(results) do
		cumulative += item.Chance
		if roll <= cumulative then
			resultItem = item.Name
			break
		end
	end

	if not resultItem then
		resultItem = results[1] and results[1].Name
	end

	return resultItem, RollMutation(mutationPercents)
end

function Machine:ClaimRewardToHands(player)
	local char = player and player.Character
	if not (char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChildOfClass("Humanoid")) then
		return false, "Respawn puis reessaie de claim la fusion"
	end

	local carryType = char:GetAttribute("Type")
	if
		char:GetAttribute("Grab")
		or char:GetAttribute("InPlace") == true
		or BrairotSelect:GetGrabModel(char)
		or BrairotSelect:GetPlace(char)
		or carryType == "Buy"
		or carryType == "Steal"
		or carryType == "InPlace"
	then
		return false, "Tu portes deja un brainrot"
	end

	local resultName, resultMutation = self:Fuse(player)
	if not resultName then
		return false, resultMutation
	end

	local resultModel = BrairotSelect:GetBrainrot(resultName, resultMutation or "Normal")
	if not resultModel then
		return false, "Impossible de creer le brainrot fusionne"
	end

	local profile = DataManager:GetProfile(player)
	local data = profile and profile.Data
	if not (data and data.Fuse and typeof(data.Fuse.Fusing) == "table") then
		resultModel:Destroy()
		return false, "Aucune fusion a claim"
	end

	local fusingItems = table.clone(data.Fuse.Fusing)
	self:RemoveAllBrainrot(player, fusingItems)
	data.Fuse.Fusing = {}
	data.Fuse.FuseEndTime = 0
	data.Fuse.FuseMode = "None"
	self:RefreshBaseAndUi(player)

	local slots = BrairotSelect:GetSlotsTable(1)
	char:SetAttribute("InPlace", false)
	char:SetAttribute("Type", "Buy")
	BrairotSelect:SetInfo(char, resultName, resultMutation or "Normal", slots)
	BrairotSelect:GrabModel(char, resultModel)

	return true, `Fusion terminee : {resultName}. Ramene-le a ta base.`
end

function Machine:InitTime(player)
	local profile = DataManager:GetProfile(player)
	if not profile then
		return false
	end

	local data = profile.Data
	if data and data.Fuse and data.Fuse.FuseMode ~= "None" then
		self:SyncFuseState(player)
	end
end

function Machine:Init(player)
	local machine = self:GetOrCreate()
	ServiceTable.RemoteEvent = myServices:LoadService("RemoteEvent") or myServices:GetService("RemoteEvent")

	if not machine.Initialized then
		machine.Initialized = true
		machine:Triggered()
		machine:Touched()
	end

	if player then
		task.delay(1, function()
			local profile = DataManager:GetProfile(player)
			local data = profile and profile.Data

			if data then
				machine:Update(data, player)
				machine:InitTime(player)
			end
		end)
	end

	return machine
end

return Machine
