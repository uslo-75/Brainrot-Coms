local RollModule = {}

local ServerStorage = game:GetService("ServerStorage")

local BrainrotList = require(ServerStorage:WaitForChild("List"):WaitForChild("BrainrotList"))
local SlotModule = require(script:WaitForChild("SlotModule"))
local MutationModule = require(script:WaitForChild("Mutation"))
local AuraList = require(game.ServerStorage.List.AuraList)
local LuckBuff = require(game.ServerStorage.Module.LuckBuff)

local function Spining(luckBuff)
	luckBuff = luckBuff or 1

	local total = 0
	local adjusted = {}

	for name, brainrot in pairs(BrainrotList) do
		local newChance = brainrot.Chance ^ (1 / luckBuff)
		adjusted[name] = newChance
		total += newChance
	end

	local roll = math.random() * total
	local current = 0

	for name, brainrot in pairs(BrainrotList) do
		current += adjusted[name]
		if roll <= current then
			return name, brainrot
		end
	end

	return next(BrainrotList)
end

local function AuraSpin(luckBuff)
	luckBuff = luckBuff or 1

	local total = 0
	local adjusted = {}

	for name, aura in pairs(AuraList) do
		local newChance = aura.Chance ^ (1 / luckBuff)
		adjusted[name] = newChance
		total = total + newChance
	end

	local roll = math.random() * total
	local current = 0

	for name, aura in pairs(AuraList) do
		current = current + adjusted[name]
		if roll <= current then
			return name, aura
		end
	end

	
	return next(AuraList)
end

function RollModule.SpinAura(number)
	local AuraSelect = {}
	
	for i = 1, number do
		local AuraName, AuraData = AuraSpin()
		if AuraName and AuraData then
			table.insert(AuraSelect, {
				Name = AuraName,
				ImageId = AuraData.ImageId,
			})
		end
	end
	
	return AuraSelect, AuraSelect[number]
end

function RollModule.Roll(number, player)
	local BrainrotSelect = {}
	local playerLuck = LuckBuff:AllLuck(player)

	for i = 1, number do
		local BrainrotName, BrainrotData = Spining(playerLuck)
		if BrainrotName and BrainrotData then
			local MutaSelect = MutationModule:RandomMutation(playerLuck)
			local M = MutationModule:GetMuta(MutaSelect)
			local SlotCount = SlotModule:RandomSlot(playerLuck)
			local TableRecup = {
				Name = BrainrotName,
				Data = BrainrotData,
				Mutation = MutaSelect,
				Slots = tonumber(SlotCount),
				Multiplicateur = M and M.Multiplicateur or 1,
			}
			table.insert(BrainrotSelect, TableRecup)
		end
	end


	return BrainrotSelect
end

return RollModule
