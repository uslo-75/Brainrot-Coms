local Players = game:GetService("Players")
local RP = game:GetService("ReplicatedStorage")

local myServices = require(RP:WaitForChild("MyService"):WaitForChild("MyService"))
local GameConfig = require(RP:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local TextModule = require(RP.Module.TextModule)
local ViewtPortModule = require(RP.Module.ViewPortModule)
local MessageModule = require(RP.Module.MessageModule)
local PreviewModel = require(RP:WaitForChild("Module"):WaitForChild("PreviewModel"))

local player = Players.LocalPlayer

local RebirthManager = {}
local ServiceTable = {}
local ItemsId = {}
local DEFAULT_WAIT_TIMEOUT = GameConfig.Shared.DefaultWaitTimeout

local function disconnectConnections(connectionList)
	for _, connection in ipairs(connectionList) do
		connection:Disconnect()
	end

	table.clear(connectionList)
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

local function getLeaderstat(statName, timeout)
	local leaderstats = player:FindFirstChild("leaderstats") or waitForChildQuiet(player, "leaderstats", timeout)
	if not leaderstats then
		return nil
	end

	return leaderstats:FindFirstChild(statName) or waitForChildQuiet(leaderstats, statName, timeout)
end

local function Clear(Frame)
	for i, v in pairs(Frame:GetChildren()) do
		if v:IsA("Frame") then
			v:Destroy()
		end
	end
end

function RebirthManager:Update()
	local RebirthFrame = self.RebirthFrame
	if not RebirthFrame then
		return
	end

	local Rebirth = getLeaderstat("Rebirth", DEFAULT_WAIT_TIMEOUT)
	if not Rebirth then
		return
	end
	
	local Requirements = RebirthFrame.Background.Container.Requirements
	local RewardsFrame = RebirthFrame.Background.Container.Rewards
	
	
	local function UpdateAffiche()
		local Info = ServiceTable["RemoteEvent"]:InvokeServer("GetInfo", "Rebirth")
		
		if Info then
			RebirthFrame.Background.Container.Visible = true
			RebirthFrame.Background.Maxed.Visible = false
			
			Clear(Requirements)
			Clear(RewardsFrame)
			
			local TemplateRequireCash = RebirthFrame.Background.Container.RequireTemplate:Clone()
			TemplateRequireCash.Parent = Requirements
			TemplateRequireCash.Visible = true
			TemplateRequireCash.Amount.Text = TextModule:Suffixe(Info.Required.Cash).." $"
			TemplateRequireCash.Name = "Cash"
			TemplateRequireCash.Title.Text = "Cash"
			TemplateRequireCash.Icon.Image = "rbxassetid://105586963354597"
			
			local TemplateRewardCash = RebirthFrame.Background.Container.RequireTemplate:Clone()
			TemplateRewardCash.Parent = RewardsFrame
			TemplateRewardCash.Visible = true
			TemplateRewardCash.Amount.Text = TextModule:Suffixe(Info.Reward.Cash).." $"
			TemplateRewardCash.Name = "Cash"
			TemplateRewardCash.Title.Text = "Cash"
			TemplateRewardCash.Icon.Image = "rbxassetid://105586963354597"
			
			for _, brainrotName in pairs(Info.Required.Brainrot) do
				local TemplateRequireBrainrot = RebirthFrame.Background.Container.RequireTemplate:Clone()
				TemplateRequireBrainrot.Parent = Requirements
				TemplateRequireBrainrot.Visible = true
				TemplateRequireBrainrot.Amount.Visible = false
				TemplateRequireBrainrot.Name = brainrotName
				TemplateRequireBrainrot.Title.Text = "???"
				
				local Model = PreviewModel:GetModel("Rebirth_" .. brainrotName, brainrotName, "Normal")
				
				if Model then
					local preview = ViewtPortModule.new(Model, TemplateRequireBrainrot.ViewportFrame, true)
					
					preview:Start(Vector3.new(0, 6, 5.5))
				end
				
			end
			
			for _, items in pairs(Info.Reward.Items) do
				local TemplateRewardItems = RebirthFrame.Background.Container.RequireTemplate:Clone()
				TemplateRewardItems.Parent = RewardsFrame
				TemplateRewardItems.Visible = true
				TemplateRewardItems.Amount.Visible = false
				TemplateRewardItems.Name = items
				TemplateRewardItems.Title.Text = items
				
				if ItemsId[items] then
					TemplateRewardItems.Icon.Image = "rbxassetid://"..ItemsId[items]
				end
				
			end
			
		else
			RebirthFrame.Background.Container.Visible = false
			RebirthFrame.Background.Maxed.Visible = true
		end
		
	end
	
	UpdateAffiche()
	
	if self.RebirthChangedConnection then
		self.RebirthChangedConnection:Disconnect()
	end

	self.RebirthChangedConnection = Rebirth.Changed:Connect(UpdateAffiche)
	
end


function RebirthManager:Visible()
	local RebirthFrame = self.RebirthFrame
	local LeftButtons = self.LeftButtons
	local Requirements = RebirthFrame.Background.Container.Requirements
	
	local function UpdateAffiche()
		local succes, result = ServiceTable["RemoteEvent"]:InvokeServer("RebirthFonction", "Update")

		if succes then
			RebirthFrame.Background.Container.Rebirth.BackgroundColor3 = Color3.new(0,1,0)
		else
			RebirthFrame.Background.Container.Rebirth.BackgroundColor3 = Color3.new(1,0,0)
		end


		for _, template in pairs(Requirements:GetChildren()) do
			if template:IsA("Frame") then
				if result[template.Name] then
					template.ViewportFrame.LightColor = Color3.fromRGB(140,140,140)
					template.ViewportFrame.Ambient = Color3.fromRGB(200,200,200)
					template.Title.Text = template.Name
				else
					template.ViewportFrame.LightColor = Color3.fromRGB(0, 0, 0)
					template.ViewportFrame.Ambient = Color3.fromRGB(0, 0, 0)
					template.Title.Text = "???"
				end
			end
		end
	end
	
	UpdateAffiche()
	
	table.insert(self.Connections, LeftButtons.Rebirth.MouseButton1Click:Connect(function()
		ServiceTable["Gui"]:AnimFrame(RebirthFrame, not RebirthFrame.Visible)
		
		if RebirthFrame.Visible then
			UpdateAffiche()
		end
		
	end))
	
	table.insert(self.Connections, RebirthFrame.Background.X.MouseButton1Click:Connect(function()
		ServiceTable["Gui"]:AnimFrame(RebirthFrame, false)
	end))
	
	table.insert(self.Connections, RebirthFrame.Background.Container.Rebirth.MouseButton1Click:Connect(function()
		local succes, mess = ServiceTable["RemoteEvent"]:InvokeServer("RebirthFonction", "Rebirth")
		
		if succes then
			ServiceTable["Gui"]:AnimFrame(RebirthFrame, false)
		end
		
		if mess then MessageModule:SendMessage(player, mess, 2.5, Color3.new(1,0,0))  end
		
		if not succes and not mess then
			MessageModule:SendMessage(player, "You don't have the necessary items for rebirth !", 2.5, Color3.new(1,0,0))
		end
		
	end))
	
end

function RebirthManager:BindGui()
	local MainGui = ServiceTable["Gui"]:WaitForGuiByName("MainGui", DEFAULT_WAIT_TIMEOUT)
	if not MainGui then
		return false
	end

	if self.MainGui == MainGui and self.RebirthFrame and self.RebirthFrame.Parent then
		return true
	end

	disconnectConnections(self.Connections)

	if self.RebirthChangedConnection then
		self.RebirthChangedConnection:Disconnect()
		self.RebirthChangedConnection = nil
	end

	self.MainGui = MainGui
	self.LeftButtons = MainGui:WaitForChild("LeftButtons")
	self.RebirthFrame = MainGui:WaitForChild("Rebirth")

	self:Update()
	self:Visible()

	return true
end

function RebirthManager:ScheduleBind()
	task.spawn(function()
		for _ = 1, 30 do
			if self:BindGui() then
				return
			end

			task.wait(0.2)
		end
	end)
end

function RebirthManager:Init()
	ServiceTable["Gui"] = myServices:LoadService("Gui") or myServices:GetService("Gui")
	ServiceTable["RemoteEvent"] = myServices:LoadService("RemoteEvent") or myServices:GetService("RemoteEvent")

	self.Connections = self.Connections or {}

	if not self.Initialized then
		self.Initialized = true
		player.CharacterAdded:Connect(function()
			self:ScheduleBind()
		end)
	end

	self:ScheduleBind()
	
end

return RebirthManager
