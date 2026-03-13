local RP = game:GetService("ReplicatedStorage")
local ServiceFolder = RP:WaitForChild("MyService")
local myServices = require(ServiceFolder:WaitForChild("MyService"))
local Players = game:GetService("Players")

local GameConfig = require(RP:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local TextMoudule = require(game.ReplicatedStorage.Module.TextModule)
local GuiList = require(game.ReplicatedStorage.List.GuiList)
local MessageModule = require(game.ReplicatedStorage.Module.MessageModule)

local InteractFolder = game.Workspace.InteractFolder

local player = Players.LocalPlayer    

local ShopManager = {}
local ServiceTable = {}
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

function ShopManager:LoadItem()
	local ItemInfo = ServiceTable["RemoteEvent"]:InvokeServer("ShopFonction", "ShopList")
	local Rebirth = getLeaderstat("Rebirth", DEFAULT_WAIT_TIMEOUT)
	
	if not ItemInfo or not Rebirth then return end

	for _, child in ipairs(self.BackgroundTool.Container:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	
	local sortedKeys = {}

	for name in pairs(ItemInfo) do
		table.insert(sortedKeys, name)
	end

	table.sort(sortedKeys, function(a, b)
		return ItemInfo[a].RebrithRequire < ItemInfo[b].RebrithRequire
	end)
	
	for _, name in ipairs(sortedKeys) do
		local item = ItemInfo[name]
		if item and item.Purchasable then
			
			
			
			local Gear = self.BackgroundTool:WaitForChild("Gear"):Clone()
			Gear.Name = name
			Gear.Parent = self.BackgroundTool.Container
			Gear.Visible = true
			Gear.Title.Text = item.DisplayName
			Gear.Price.Text = TextMoudule:Suffixe(item.Price).."$"
			Gear.Icon.Image = GuiList.Settings.rtbx..tostring(item.ImageId)
			Gear.Info.Text = item.Description or "Alpha of description"
			Gear.Locked.Requirement.Text = "Rebirth "..item.RebrithRequire
			
			if Rebirth.Value >= item.RebrithRequire then
				Gear.Locked.Visible = false
			else
				Gear.Locked.Visible = true
			end
			
			
			
			Gear.Buy.Price.Text = `Buy {TextMoudule:Suffixe(item.Price)} $`
			
			table.insert(self.UiConnections, Gear.Equip.MouseButton1Click:Connect(function()
				local succes, mess = ServiceTable["RemoteEvent"]:InvokeServer("ShopFonction", "EquipTool", name, true)
				if not succes then return warn(tostring(mess)) end
				
				Gear.Unequip.Visible = true
				Gear.Equip.Visible = false
			end))
			
			table.insert(self.UiConnections, Gear.Unequip.MouseButton1Click:Connect(function()
				local succes, mess = ServiceTable["RemoteEvent"]:InvokeServer("ShopFonction", "EquipTool", name, false)
				if not succes then return warn(mess) end
				
				Gear.Unequip.Visible = false
				Gear.Equip.Visible = true
			end))
			
			table.insert(self.UiConnections, Gear.Buy.MouseButton1Click:Connect(function()
				
				if Gear.Locked.Visible == true then return end
				
				if Gear.Buy.Price.Text == "MAX" then return end
				
				local succes, mess, color3, arg1 = ServiceTable["RemoteEvent"]:InvokeServer("ShopFonction", "Buy", name)

				if mess then MessageModule:SendMessage(player, mess, 2.5, color3) end
				
				if item.MaxUse and arg1 then
					if arg1 >= item.MaxUse then
						Gear.Buy.Price.Text = "MAX"
					else
						Gear.Buy.Price.Text = `Buy {TextMoudule:Suffixe(item.Price)} $`
					end
				else
					Gear.Buy.Text = "Error"
				end

				if not succes then return end

				if item.EquipedOnce then
					Gear.Buy.Visible = false
					Gear.Equip.Visible = true
				else
					Gear.Buy.Visible = true
					Gear.Equip.Visible = false
				end
				
			end))
			
		end
	end
end

local function AddMoney(Frame, Name)
	local BigMoney = Frame:FindFirstChild("BigMoney")
	local SmallMoney = Frame:FindFirstChild("SmallMoney")
	local MoneyFrame = BigMoney:FindFirstChild(Name) or SmallMoney:FindFirstChild(Name)
	
	if MoneyFrame then
		table.insert(ShopManager.UiConnections, MoneyFrame.Buy.MouseButton1Click:Connect(function()
			ServiceTable["MarketPlaceService"]:Purchase(player, Name)
		end))
	end
end

function ShopManager:InitPassClick()
	local MoneyFrame = self.Background.Container:FindFirstChild("Money")
	local ServerLuckFrame = self.Background.Container:FindFirstChild("ServerLuck")
	local Gamepasses = self.Background.Container:FindFirstChild("Gamepasses")
	
	if Gamepasses then
		local SmallGamepasses = Gamepasses:FindFirstChild("SmallGamepasses")
		if SmallGamepasses then
			for _, frame in pairs(SmallGamepasses:GetChildren()) do
				if frame:IsA("Frame") then
					table.insert(self.UiConnections, frame.Buy.MouseButton1Click:Connect(function()
						ServiceTable["MarketPlaceService"]:Purchase(player, frame.Name)
					end))
				end
			end
		end
	end
	
	if ServerLuckFrame then
		table.insert(self.UiConnections, ServerLuckFrame.Deal.Buy.MouseButton1Click:Connect(function()
			ServiceTable.MarketPlaceService:Purchase(player, "ServerLuck")
		end))
	end
	
	if MoneyFrame then
		AddMoney(MoneyFrame, "10KCash")
		AddMoney(MoneyFrame, "100KCash")
		AddMoney(MoneyFrame, "500KCash")
		AddMoney(MoneyFrame, "1MCash")
		AddMoney(MoneyFrame, "10MCash")
	end
end

function ShopManager:Visible()
	if not self.WorldBound then
		self.WorldBound = true

		InteractFolder.RobuxShop:WaitForChild("Proximity").Special.Triggered:Connect(function()
			if self.RobuxShop then
				ServiceTable["Gui"]:AnimFrame(self.RobuxShop, not self.RobuxShop.Visible)
			end
		end)
		
		InteractFolder.ToolShop:WaitForChild("Proximity").Special.Triggered:Connect(function()
			if self.ToolShop then
				ServiceTable["Gui"]:AnimFrame(self.ToolShop, not self.ToolShop.Visible)
			end
		end)
	end
	
	table.insert(self.UiConnections, self.LeftButtons.Shop.MouseButton1Click:Connect(function()
		ServiceTable["Gui"]:AnimFrame(self.RobuxShop, not self.RobuxShop.Visible)
	end))
	
	table.insert(self.UiConnections, self.Background.X.MouseButton1Click:Connect(function()
		ServiceTable["Gui"]:AnimFrame(self.RobuxShop, false)
	end))
	
	table.insert(self.UiConnections, self.BackgroundTool.X.MouseButton1Click:Connect(function()
		ServiceTable["Gui"]:AnimFrame(self.ToolShop, false)
	end))
	
end

function ShopManager:BindGui()
	local MainGui = ServiceTable["Gui"]:WaitForGuiByName("MainGui", DEFAULT_WAIT_TIMEOUT)
	if not MainGui then
		return false
	end

	if self.MainGui == MainGui and self.RobuxShop and self.RobuxShop.Parent then
		return true
	end

	disconnectConnections(self.UiConnections)

	self.MainGui = MainGui
	self.RobuxShop = self.MainGui:WaitForChild("RobuxShop")
	self.ToolShop = self.MainGui:WaitForChild("ToolShop")
	self.Background = self.RobuxShop:WaitForChild("Background")
	self.BackgroundTool = self.ToolShop:WaitForChild("Background")
	self.LeftButtons = self.MainGui:WaitForChild("LeftButtons")

	self:Visible()
	self:LoadItem()
	self:InitPassClick()

	return true
end

function ShopManager:ScheduleBind()
	task.spawn(function()
		for _ = 1, 30 do
			if self:BindGui() then
				return
			end

			task.wait(0.2)
		end
	end)
end

function ShopManager:Init()
	ServiceTable["RemoteEvent"] = myServices:LoadService("RemoteEvent") or myServices:GetService("RemoteEvent")
	ServiceTable["Gui"] = myServices:LoadService("Gui") or myServices:GetService("Gui")
	ServiceTable["MarketPlaceService"] = myServices:LoadService("MarketPlaceService") or myServices:GetService("MarketPlaceService")

	self.UiConnections = self.UiConnections or {}

	if not self.Initialized then
		self.Initialized = true
		player.CharacterAdded:Connect(function()
			self:ScheduleBind()
		end)
	end

	self:ScheduleBind()
end

return ShopManager
