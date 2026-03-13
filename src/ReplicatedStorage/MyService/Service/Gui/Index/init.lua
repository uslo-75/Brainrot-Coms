local Players = game:GetService("Players")
local RP = game:GetService("ReplicatedStorage")
local ServiceFolder = RP:WaitForChild("MyService")
local myServices = require(ServiceFolder:WaitForChild("MyService"))
local player = Players.LocalPlayer

local Index = {}
local mountedIndexGui = nil
local mountedMainGui = nil
local initialized = false

local function mountIndex()
	local GuiService = myServices:LoadService("Gui") or myServices:GetService("Gui")
	local MainGui = GuiService and GuiService:WaitForGuiByName("MainGui", 15)

	if not MainGui then
		return false
	end

	if mountedIndexGui and mountedMainGui == MainGui and MainGui.Parent then
		return true
	end

	if mountedIndexGui and mountedIndexGui.Destroy then
		mountedIndexGui:Destroy()
	end

	local IndexGui = require(script.IndexGui)
	mountedIndexGui = IndexGui.new(MainGui)
	mountedMainGui = MainGui

	return true
end

local function mountIndexWithRetry()
	task.spawn(function()
		for _ = 1, 30 do
			if mountIndex() then
				return
			end

			task.wait(0.2)
		end
	end)
end

function Index:Init()
	if initialized then
		return
	end

	initialized = true
	mountIndexWithRetry()

	player.CharacterAdded:Connect(function()
		mountIndexWithRetry()
	end)
end

return Index
