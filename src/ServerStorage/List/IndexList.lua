local IndexList = {}

local ServerStorage = game:GetService("ServerStorage")
local RP = game:GetService("ReplicatedStorage")

local MutationModule = require(ServerStorage.Module.RollModule.Mutation)
local BrainrotList = require(ServerStorage.List.BrainrotList)

function IndexList:MutationGet()
	local Info = {}
	for name, _ in pairs(MutationModule.Mutation) do
		Info[name] = {}
	end
	
	return Info
end

function IndexList:CreateList()
	local IndexList = self:MutationGet()
	
	local count = 0
	for _ in pairs(BrainrotList) do
		count = count + 1
	end
	
	for i, _ in pairs(IndexList) do
		for name, _ in pairs(BrainrotList) do
			if IndexList[i] then
				IndexList[i][name] = true
			end
		end
	end
	
	return IndexList, count
end

return IndexList
