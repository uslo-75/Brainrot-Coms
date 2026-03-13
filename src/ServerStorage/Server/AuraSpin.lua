local RP = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BrairotList = require(ServerStorage.List.BrainrotList)
local BrairotSelect = require(ServerStorage.Module.BrainrotSelect)
local DataManager = require(ServerStorage.Data.DataManager)
local RollModule = require(ServerStorage.Module.RollModule)
local MessageModule = require(RP.Module.MessageModule)

local AuraSpin = {}
local Spining = {}
local C = 1 + (10/100)

local function GetMuta(player, position)
	local brairotData = DataManager.GetBrainrot(player, position)
	
	if brairotData then
		local Mutation = brairotData.Mutation
		return Mutation
	end
	return "Normal"
end

function AuraSpin:Init(player, ...)
	local Halls = {...}
	local EventType = Halls[1]
	
	if EventType == "RollAll" then
		if Spining[player] then
			return nil, "Error !"
		end

		Spining[player] = true
		task.delay(.35*7, function()
			Spining[player] = false
		end)

		local profile = DataManager:GetProfile(player)
		if not profile or not profile.Data then
			return nil, "Error !"
		end
		local BrairotData = BrairotList[profile.Data.AuraSpin.Name]
		local CashRequire = BrairotData and BrairotData.Price * C or 0
		local results = {}
		local succes = true
		local message = ""
		local Cash = player:WaitForChild("leaderstats"):WaitForChild("Cash")
		local Multiplicated = {}
		local brairotInfo = DataManager.GetBrainrot(player, profile.Data.AuraSpin.Position) or { Slots = {} }
		local name = profile.Data.AuraSpin.Name
		local NewCash = 0
		
		if name == "" then
			return nil
		end
		
		if Cash.Value >= CashRequire then
			Cash.Value -= CashRequire
			succes = true
			local CashPerSeconde =
				BrairotList[name] and BrairotList[name].CashPerSeconde or 0
			local Mutation = GetMuta(player, brairotInfo.Position)

			table.insert(Multiplicated, Mutation)

			for slotName, _ in pairs(brairotInfo.Slots) do


				if brairotInfo then
					local AuraList, AuraSelect = RollModule.SpinAura(7)
					table.insert(Multiplicated, AuraSelect.Name)

					brairotInfo.Slots[slotName] = AuraSelect.Name

					results[slotName] = {
						AuraList = AuraList,
						Result = AuraSelect,
					}
				end
			end
			
			NewCash = CashPerSeconde * BrairotSelect:GetMultiplicater(Multiplicated)
		else
			MessageModule:SendMessage(player, "Not enough Cash !", 2, Color3.new(1,0,0))
			return false, "Cash insuffisant"
		end

		return succes, message, results, NewCash
	end

end

return AuraSpin
