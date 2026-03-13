local RP = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TS = game:GetService("TweenService")

local myServices = require(RP:WaitForChild("MyService"):WaitForChild("MyService"))

local BrairotSelect = require(ServerStorage.Module.BrainrotSelect)
local DataManager = require(ServerStorage.Data.DataManager)
local ViewPortModule = require(RP.Module.ViewPortModule)
local BrairotList = require(ServerStorage.List.BrainrotList)
local MessageModule = require(RP.Module.MessageModule)
local RollModule = require(ServerStorage.Module.RollModule)

local AuraSpinController = {}
local ServiceTable = {}
AuraSpinController.Initialized = false

local Spining = {}
local Hits = {}

local Pourcent = 1 + 10/100

local Model = Workspace.InteractFolder.AuraSpin

local function CashRequired(Name)
	if BrairotList[Name] then
		return BrairotList[Name].Price * Pourcent
	end
	return 1e100
end

local function GetRemoteEvent()
	if ServiceTable["RemoteEvent"] then
		return ServiceTable["RemoteEvent"]
	end

	ServiceTable["RemoteEvent"] =
		myServices:LoadService("RemoteEvent")
		or myServices:GetService("RemoteEvent")
		or require(RP:WaitForChild("MyService"):WaitForChild("Service"):WaitForChild("RemoteEvent"))

	return ServiceTable["RemoteEvent"]
end

local function BuildAuraSpinPayload(player, data)
	if not data or not data.AuraSpin then
		return nil
	end

	local name = data.AuraSpin.Name
	local position = data.AuraSpin.Position

	if name == "" or position == "" then
		return nil
	end

	local multipliers = {}
	local brairotInfo = BrairotList[name]
	local brairotData = DataManager.GetBrainrot(player, position)

	if not brairotInfo or not brairotData then
		return nil
	end

	local mutation = brairotData.Mutation
	local rarity = brairotInfo.Rarity
	local price = brairotInfo.Price
	local slots = brairotData.Slots or {}

	table.insert(multipliers, mutation)

	for _, value in pairs(slots) do
		table.insert(multipliers, value)
	end

	local cashPerSeconde = brairotInfo.CashPerSeconde * BrairotSelect:GetMultiplicater(multipliers)
	local cashRequireds = CashRequired(name)

	return name, mutation, rarity, cashPerSeconde, price, slots, cashRequireds
end

local function PushAuraSpinState(player, remoteEvent, eventType, data)
	local payload = table.pack(BuildAuraSpinPayload(player, data))
	if payload.n == 0 or payload[1] == nil then
		return false
	end

	remoteEvent:InvokeClient("AuraSpin", player, eventType, table.unpack(payload, 1, payload.n))
	return true
end

local function TryAssignCarriedBrainrot(player, char, remoteEvent)
	if not player or not char then
		return false
	end

	local profile = DataManager:GetProfile(player)
	local data = profile and profile.Data
	if not data then
		return false
	end

	if data.AuraSpin.Name ~= "" and data.AuraSpin.Position ~= "" then
		return false
	end

	local brairotGrab = BrairotSelect:GetGrabModel(char)
	local brairotPlace = BrairotSelect:GetPlace(char)

	if not brairotGrab or not brairotPlace then
		return false
	end

	if char:GetAttribute("Type") ~= "InPlace" then
		return false
	end

	if brairotGrab:GetAttribute("Owner") ~= player.Name then
		return false
	end

	local name = brairotGrab.Name
	local position = brairotGrab:GetAttribute("Position")
	local brairotInfo = BrairotList[name]
	local brairotData = DataManager.GetBrainrot(player, position)

	if not name or not position or not brairotInfo or not brairotData then
		return false
	end

	brairotPlace:SetAttribute("Type", "InMachine")
	brairotPlace:SetAttribute("Mode", "AuraSpin")
	brairotPlace:SetAttribute("InPlace", false)

	BrairotSelect:UnGrab(char)
	BrairotSelect:ClearGrab(char)
	BrairotSelect:RemovePlace(char)
	BrairotSelect:RemoveInfo(char)

	char:SetAttribute("InPlace", false)
	char:SetAttribute("Type", "None")

	data.AuraSpin.Name = name
	data.AuraSpin.Position = position

	PushAuraSpinState(player, remoteEvent, "Update", data)
	remoteEvent:InvokeClient("AuraSpin", player, "BrairotPreview", true, brairotData.Mutation, name, brairotData.Slots or {})
	MessageModule:SendMessage(player, "brainrot successfully added!", 1.8, Color3.new(0,1,0))

	return true
end

function AuraSpinController:Triggered()
	Model.AuraSpin.Special.Triggered:Connect(function(player)
		local remoteEvent = GetRemoteEvent()
		if not remoteEvent then
			warn("[AuraSpinController]: RemoteEvent unavailable on Triggered")
			return
		end

		remoteEvent:InvokeClient("AuraSpin", player, "Visible", true)
		
		local char = player.Character or player.CharacterAdded:Wait()
		if TryAssignCarriedBrainrot(player, char, remoteEvent) then
			return
		end

		local profile = DataManager:GetProfile(player)
		local data = profile and profile.Data
		
		if not PushAuraSpinState(player, remoteEvent, "UpdateInfo", data) then
			remoteEvent:InvokeClient("AuraSpin", player, "Empty")
		end
		
	end)
end

function AuraSpinController:Touched()
	local Hitbox = Model.Asset:FindFirstChild("Hitbox")
	
	if Hitbox then
		Hitbox.Touched:Connect(function(hit)
			local char = hit and hit.Parent
			if char and char:FindFirstChildOfClass("Humanoid") then
				if not Hits[char] then
					Hits[char] = true
					
					local BrairotGrab = BrairotSelect:GetGrabModel(char)
					local BrairotPlace = BrairotSelect:GetPlace(char)
					local player = Players:GetPlayerFromCharacter(char)
					local Multiplicated = {}
					
					if player and BrairotGrab and BrairotPlace then
						local profile = DataManager:GetProfile(player)
						local data = profile and profile.Data
						
						if data and data.AuraSpin.Name ~= "" and data.AuraSpin.Position ~= "" then
							MessageModule:SendMessage(player, "The place is already occupied !", 1.8, Color3.new(1,0,0))
							return
						end
						
						if char:GetAttribute("Type") == "InPlace" and BrairotGrab:GetAttribute("Owner") == player.Name then
							local remoteEvent = GetRemoteEvent()
							if not remoteEvent then
								warn("[AuraSpinController]: RemoteEvent unavailable on Touched")
								return
							end

							TryAssignCarriedBrainrot(player, char, remoteEvent)
						end
					end
					
					task.delay(1, function()
						Hits[char] = false
					end)
				end
				
			end
			
		end)
	end
	
end

function AuraSpinController:Init()
	if self.Initialized then
		return true
	end

	self.Initialized = true
	
	ServiceTable["RemoteEvent"] = GetRemoteEvent()
	
	
	self:Touched()
	self:Triggered()
end

return AuraSpinController
