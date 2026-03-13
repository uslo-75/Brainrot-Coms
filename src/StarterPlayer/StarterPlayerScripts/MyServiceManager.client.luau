local Players = game:GetService("Players")
local RP = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local myserviceFolder = RP:WaitForChild("MyService")
local myServices = require(myserviceFolder:WaitForChild("MyService"))

local isLoad = false

local function loadServices()
	if isLoad then
		return
	end

	isLoad = true
	myServices:FetchAllServices()
end

loadServices()

player.CharacterAdded:Connect(function()
	loadServices()
end)
