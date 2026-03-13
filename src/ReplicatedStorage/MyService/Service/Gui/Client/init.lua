--//[Services]//--

local Players = game:GetService("Players")
local RP = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

--//[Players]//--

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")

--//[Modules]//--

local ZoneController = require(script:WaitForChild("ZoneController"))
local myServices = require(RP:WaitForChild("MyService"):WaitForChild("MyService"))
local MessageModule = require(RP.Module.MessageModule)

--Client

local Client = {}
local ServicesTable = {}
local Settings = {
	Text = {
		SafeZone = 'you are in <font color="#00FF00">safe</font> zone'
	},
}

local function bindCharacter(newChar)
	char = newChar
end

local function AfficheZone(name, value)
	local Mess = Settings.Text[name]
	
	local RollGui = ServicesTable["Gui"] and ServicesTable["Gui"]:GetGuiByName("RollGui")
	
	if not name then
		return
	end
	
	if value and Mess then
		RollGui.Affiche.Text = Mess
		
		if name == "SafeZone" then
			if RollGui then
				RollGui.Enabled = true
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
				char.Humanoid:UnequipTools()
			end
		end
		
	else
		RollGui.Affiche.Text = ""
		
		if name == "SafeZone" then
			if RollGui then
				RollGui.Enabled = false
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
			end
		end
	end
	
end

function Client:Zone()
	ZoneController.EnterZone.Event:Connect(function(zoneName)
		char:SetAttribute("CurrentZone", zoneName)
		AfficheZone(zoneName, true)
	end)
	
	ZoneController.LeaveZone.Event:Connect(function(zoneName)
		char:SetAttribute("CurrentZone", "")
		AfficheZone(zoneName, nil)
	end)
	
end

function Client:AllInit()
	for _, module in pairs(script:GetChildren()) do
		if module:IsA("ModuleScript") then
			local module = require(module)
			if module["Init"] then
				task.spawn(function()
					module:Init()
				end)
			end
		end
	end
end

function Client:InitService()
	ServicesTable["Gui"] = myServices:LoadService("Gui") or myServices:GetService("Gui")
end

function Client:Init()
	self:InitService()
	self:AllInit()
	self:Zone()
	player.CharacterAdded:Connect(bindCharacter)
	return true
end

return Client
