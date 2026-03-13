local ToolEvent = {}
local modules = {}
local ToolsModuleFolder = game.ServerStorage.Module.Tools
local ItemsInfo = require(game.ServerStorage.List.ItemsInfo)

task.spawn(function()
	for _, module in pairs(ToolsModuleFolder:GetChildren()) do
		if module:IsA("ModuleScript") then
			modules[module.Name] = require(module)
		end
	end
end)

function ToolEvent:Init(player, ...)
	local Halls = {...}
	local EventType = Halls[1]
	local char : Model = player.Character or player.CharacterAdded:Wait()
	
	if EventType == "Active" then
		local ToolName = Halls[2] or "ToolName"
		local ToolModel = char:FindFirstChild(ToolName) or char:FindFirstChildOfClass("Tool")
		local ToolInfo = ItemsInfo[ToolName]
		
		if not ToolInfo or not ToolModel then warn(`Pas de model ou de ToolInfo trouver au nom de {ToolName} !`) return end
		
		local ToolModule = modules[ToolName]
		
		if ToolModule then
			ToolModule:Init(player, ToolModel, ToolInfo)
		end
		
	end
end

return ToolEvent
