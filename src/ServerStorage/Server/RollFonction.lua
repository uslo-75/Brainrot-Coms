local RollFonction = {}

local Debris = game:GetService("Debris")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local RollModule = require(ServerStorage.Module.RollModule)
local BrainrotList = require(ServerStorage.List.BrainrotList)
local BrairotSelect = require(ServerStorage.Module.BrainrotSelect)
local BaseModule = require(ServerStorage.Module.GameHandler.Base)
local DataManager = require(ServerStorage.Data.DataManager)
local PassId = require(ServerStorage.List.PassId)
local BrainrotSoundResolver = require(ReplicatedStorage:WaitForChild("Module"):WaitForChild("BrainrotSoundResolver"))

local RollSelect = setmetatable({}, { __mode = "k" })
local DB = setmetatable({}, { __mode = "k" })
local AUTO_ROLL_GROUP_ID = 32991977

local function ClearRollSelection(player)
	RollSelect[player] = nil
end

local function PlayGlobalBrainrotSound(char, result)
	if not (char and result) then
		return nil
	end

	local rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
	if not rootPart then
		return nil
	end

	local sound = BrainrotSoundResolver.Resolve(result)
	if not sound then
		return nil
	end

	local soundClone = sound:Clone()
	soundClone.Looped = false
	soundClone.Playing = false
	soundClone.TimePosition = 0
	soundClone.Parent = rootPart

	local cleanupTime = soundClone.TimeLength > 0 and (soundClone.TimeLength + 2) or 10
	Debris:AddItem(soundClone, cleanupTime)
	soundClone:Play()

	return soundClone
end

local function HasGamePass(player, passName)
	local passInfo = PassId[passName]
	if not passInfo or passInfo.DevProduct then
		return false
	end

	local success, hasPass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passInfo.Id)
	end)

	return success and hasPass or false
end

local function IsInAutoRollGroup(player)
	if not player or AUTO_ROLL_GROUP_ID <= 0 then
		return false
	end

	local success, isMember = pcall(function()
		return player:IsInGroup(AUTO_ROLL_GROUP_ID)
	end)

	return success and isMember or false
end

local function ResolveRollCount(player, requestedCount)
	local profile = DataManager:GetProfile(player)
	local data = profile and profile.Data
	local fastRollEnabled = data and data.Settings and data.Settings.FastRoll

	if requestedCount == 3 and fastRollEnabled then
		return 3
	end

	return 7
end

local function HassFull(player)
	
	local MyBases = BaseModule.GetBase(player)
	
	if MyBases then
		for _, v in pairs(MyBases.StockBrainrot:GetChildren()) do
			if not v:GetAttribute("Enter") then
				return false
			end
		end
	end
	
	return true
end

function BrairotSkip(player, BrairotName)
	local BrairotData = BrainrotList[BrairotName]
	local profile = DataManager:GetProfile(player)
	local Data = profile and profile.Data
	
	if Data then
		if Data.Settings.SkipBrainrot >= BrairotData.CashPerSeconde then
			return true
		end
	end
	return false
end

function RollFonction:Init(player, ...)
	local Halls = {...}
	local EventType = Halls[1]
	local char : Model = player.Character or player.CharacterAdded:Wait()
	
	if EventType == "Roll" then
		ClearRollSelection(player)

		if not HassFull(player) then
			local Roll = player:WaitForChild("leaderstats"):WaitForChild("Roll")
			local number = ResolveRollCount(player, Halls[2])
			local result = RollModule.Roll(number, player)
			local items = result[number]

			Roll.Value += 1

			RollSelect[player] = items

			return result, items, BrainrotList[items.Name], BrairotSkip(player, items.Name)
		else
			return nil
		end
	elseif EventType == "CanRoll" then
		
		if HassFull(player) then
			return false, "Base full !"
		end
		return true
	elseif EventType == "Buy" then
		local result = RollSelect[player]
		local itemsInfo = result and BrainrotList[result.Name]
		local Cash = player:WaitForChild("leaderstats"):WaitForChild("Cash")

		if result and itemsInfo then
			if not DB[player] then
				DB[player] = true
				task.delay(1.5, function() DB[player] = false end)
				if Cash.Value >= itemsInfo.Price then
					Cash.Value -= itemsInfo.Price

					local NewBrairot = BrairotSelect:GetBrainrot(result.Name, result.Mutation)
					if not NewBrairot then
						Cash.Value += itemsInfo.Price
						return false, "Brainrot model missing"
					end

					local SlotTable = BrairotSelect:GetSlotsTable(result.Slots)
					char:SetAttribute("Type", "Buy")
					BrairotSelect:SetInfo(player.Character, result.Name, result.Mutation, SlotTable)

					BrairotSelect:GrabModel(player.Character, NewBrairot)
					PlayGlobalBrainrotSound(char, {
						Name = result.Name,
						Data = itemsInfo,
					})
					ClearRollSelection(player)
					return true
				else
					return false, "Not enough Cash"
				end
			end
		end
		return nil, "Error retry please"
	elseif EventType == "ClearSelection" then
		ClearRollSelection(player)
		return true
	elseif EventType == "FastRoll" then
		
		local Roll = player:WaitForChild("leaderstats"):WaitForChild("Roll")
		local profile = DataManager:GetProfile(player)
		local Data = profile and profile.Data
		
		if not Data then
			warn("data")
			return nil
		end
		
		if HasGamePass(player, "FastRoll") then
			Data.Settings.FastRoll = not Data.Settings.FastRoll
			return true, Data.Settings.FastRoll
		end
		
		if Roll.Value >= 1000 then
			
			Data.Settings.FastRoll = not Data.Settings.FastRoll
			
			return true, Data.Settings.FastRoll
		end
		return false, Data.Settings.FastRoll
	elseif EventType == "AutoRoll" then
		local Roll = player:WaitForChild("leaderstats"):WaitForChild("Roll")
		local profile = DataManager:GetProfile(player)
		local Data = profile and profile.Data
		
		if not Data then
			return nil
		end

		if Roll.Value >= 100 or IsInAutoRollGroup(player) then

			Data.Settings.AutoRoll = not Data.Settings.AutoRoll

			return true, Data.Settings.AutoRoll
		end
		return false, Data.Settings.AutoRoll
	elseif EventType == "DesactiveAutoRoll" then
		local profile = DataManager:GetProfile(player)
		local Data = profile and profile.Data
		
		if Data then
			Data.Settings.AutoRoll = false
			return true, Data.Settings.AutoRoll
		end
	
	end
	
end

return RollFonction
