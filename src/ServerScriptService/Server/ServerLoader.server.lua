local RP = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local myserviceFolder = RP:WaitForChild("MyService")
local myServices = require(myserviceFolder:WaitForChild("MyService"))

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		return folder
	end

	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function moveBrainrotChildren(sourceFolder, targetFolder)
	for _, child in ipairs(sourceFolder:GetChildren()) do
		local existing = targetFolder:FindFirstChild(child.Name)

		if child:IsA("Folder") then
			local destination = existing
			if not (destination and destination:IsA("Folder")) then
				destination = ensureFolder(targetFolder, child.Name)
			end

			moveBrainrotChildren(child, destination)
		elseif not existing then
			child.Parent = targetFolder
		end
	end
end

local function migrateBrainrotModel()
	local replicatedRoot = RP:FindFirstChild("BrainrotModel")
	if not replicatedRoot then
		return
	end

	local serverRoot = ensureFolder(ServerStorage, "BrainrotModel")
	moveBrainrotChildren(replicatedRoot, serverRoot)
	replicatedRoot:ClearAllChildren()
end

migrateBrainrotModel()

local CashHandler = require(game.ServerStorage.Module.GameHandler.CashHandler)
CashHandler:Start()

local GamePassHandler = require(ServerStorage.Module.GameHandler.GamePassHandler)
local DataManager = require(ServerStorage.Data.DataManager)
local GameHandle = require(ServerStorage.Module.GameHandler)

local loadServices = myServices:FetchAllServices()
