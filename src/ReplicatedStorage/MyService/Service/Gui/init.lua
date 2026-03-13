local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local RP = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")

local GameConfig = require(RP:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local GuiFolder = nil
local DEFAULT_WAIT_TIMEOUT = GameConfig.Shared.DefaultWaitTimeout

local Sounds = require(RP.Module.Sounds)
local TextModule = require(RP.Module.TextModule)
local GuiList = require(RP:WaitForChild("List"):WaitForChild("GuiList"))

local Gui = {}
local connections = {} 
local OriginsPosition = {}
local db = {}
local cashConnection = nil
local guiRefreshInitialized = false

local InfoFrame = TweenInfo.new(.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local function waitForChildQuiet(parent, childName, timeout)
	local deadline = os.clock() + (timeout or DEFAULT_WAIT_TIMEOUT)
	local child = parent and parent:FindFirstChild(childName)

	while parent and not child and os.clock() < deadline do
		task.wait(0.1)
		child = parent:FindFirstChild(childName)
	end

	return child
end

local function getGuiFolder(timeout)
	if GuiFolder and GuiFolder.Parent == playerGui then
		return GuiFolder
	end

	GuiFolder = playerGui:FindFirstChild("Gui") or waitForChildQuiet(playerGui, "Gui", timeout)
	return GuiFolder
end

local function preserveScreenGuis(guiFolder)
	if not guiFolder then
		return
	end

	for _, descendant in ipairs(guiFolder:GetDescendants()) do
		if descendant:IsA("ScreenGui") then
			descendant.ResetOnSpawn = false
		end
	end
end

local function getLeaderstat(statName, timeout)
	local leaderstats = player:FindFirstChild("leaderstats") or waitForChildQuiet(player, "leaderstats", timeout)
	if not leaderstats then
		return nil
	end

	return leaderstats:FindFirstChild(statName) or waitForChildQuiet(leaderstats, statName, timeout)
end

function Gui:GetGuiByName(_name)
	local guiFolder = getGuiFolder()
	return guiFolder and guiFolder:FindFirstChild(_name)
end

function Gui:WaitForGuiByName(name, timeout)
	local deadline = os.clock() + (timeout or DEFAULT_WAIT_TIMEOUT)
	local gui = self:GetGuiByName(name)

	while not gui and os.clock() < deadline do
		task.wait(0.1)
		gui = self:GetGuiByName(name)
	end

	return gui
end

function Gui:LabelColor(Label : Instance, name)
	local Gradien = Label:FindFirstChild("Gradien") or Label:FindFirstChildOfClass("UIGradient") or Label:FindFirstChildWhichIsA("UIGradient")
	if not Gradien then
		Gradien = Instance.new("UIGradient")
		Gradien.Name = "Gradien"
		Gradien.Parent = Label 
	end
	if GuiList.Colors[name] then
		Gradien.Color = GuiList.Colors[name]
		self:Orientation(Gradien) 
		return true 
	end
	return false
end

function Gui:Orientation(Gradient)
	if not Gradient or not Gradient:IsA("UIGradient") then
		return
	end

	if connections[Gradient] then
		connections[Gradient].tween:Cancel()
		connections[Gradient].destroy:Disconnect()
		connections[Gradient] = nil
	end

	Gradient.Rotation = 0

	local tweenInfo = TweenInfo.new(
		2,
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.InOut,
		-1 -- boucle infinie
	)

	local tween = TS:Create(Gradient, tweenInfo, {
		Rotation = 360
	})

	local destroyConn = Gradient.Destroying:Connect(function()
		if connections[Gradient] then
			connections[Gradient].tween:Cancel()
			connections[Gradient] = nil
		end
	end)

	tween:Play()

	connections[Gradient] = {
		tween = tween,
		destroy = destroyConn
	}
end

function Gui:Core()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
end

function Gui:InitModule()
	for _, module in pairs(script:GetChildren()) do
		if module:IsA("ModuleScript") then
			local moduleScript = require(module)
			
			task.spawn(function()
				if moduleScript["Init"] then
					moduleScript:Init()
				end
			end)
			
		end
	end
end

function Gui:FrameVisible(name)
	local MainGui = Gui:GetGuiByName("MainGui")
	if not MainGui then
		return
	end

	local WhiteList = { "AuraSpin", "FuseMachine", "IndexFrame", "Rebirth", "ToolShop", "RobuxShop", "SettingsFrame", "ToolShop" }

	for _, frame in pairs(MainGui:GetChildren()) do
		if frame:IsA("Frame") then
			for _, whiteName in pairs(WhiteList) do
				if frame.Name == whiteName and frame.Name ~= name then
					task.spawn(function()
						Gui:AnimFrame(frame, false)
					end)
				end
			end
		end
	end
end


function Gui:AnimFrame(Frame : Frame, value)
	if not db[Frame] then
		db[Frame] = true
		if not OriginsPosition[Frame] then
			OriginsPosition[Frame] = Frame.Position
		end

		local Origins = OriginsPosition[Frame]
		local Default = UDim2.new(Origins.X.Scale, Origins.X.Offset, Origins.Y.Scale, Origins.Y.Offset - 1000)
		
		Sounds.Play("ClickSound")
		
		if value then
			Gui:FrameVisible(Frame.Name)
			Frame.Visible = true
			Frame.Position = Default
			local Tween = TS:Create(Frame, InfoFrame, {Position = Origins})
			Tween:Play()
			Tween.Completed:Wait()
			db[Frame] = false
		else
			local Tween = TS:Create(Frame, InfoFrame, {Position = Default})
			Tween:Play()
			Tween.Completed:Wait()
			db[Frame] = false
			Frame.Visible = false
			Frame.Position = Origins
		end
	end
end



function Gui:CashLabel()
	local MainGui = self:WaitForGuiByName("MainGui", DEFAULT_WAIT_TIMEOUT)
	local CashLabel = MainGui and MainGui:WaitForChild("CashLabel")
	if not CashLabel then return end
	
	local Cash = getLeaderstat("Cash", DEFAULT_WAIT_TIMEOUT)
	if not Cash then
		return
	end

	if cashConnection then
		cashConnection:Disconnect()
		cashConnection = nil
	end
	
	CashLabel.Text = tostring(TextModule:Suffixe(Cash.Value)).." $"
	
	cashConnection = Cash:GetPropertyChangedSignal("Value"):Connect(function()
		CashLabel.Text = tostring(TextModule:Suffixe(Cash.Value)).." $"
	end)
end

local function initGuiRefresh()
	if guiRefreshInitialized then
		return
	end

	guiRefreshInitialized = true

	playerGui.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ScreenGui") then
			descendant.ResetOnSpawn = false
		end

		if descendant.Name == "CashLabel" then
			task.defer(function()
				Gui:CashLabel()
			end)
		end
	end)

	playerGui.ChildAdded:Connect(function(child)
		if child.Name == "Gui" then
			preserveScreenGuis(child)
			task.defer(function()
				Gui:CashLabel()
			end)
		end
	end)

	player.CharacterAdded:Connect(function()
		task.defer(function()
			Gui:CashLabel()
		end)
	end)
end

function Gui:Init()
	if not getGuiFolder(DEFAULT_WAIT_TIMEOUT) then
		warn("[Gui]: Gui folder not found in PlayerGui")
		return false
	end

	preserveScreenGuis(GuiFolder)
	initGuiRefresh()
	self:Core()
	self:InitModule()
	
	self:CashLabel()
	
	return true
end

return Gui
