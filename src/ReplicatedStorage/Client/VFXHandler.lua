local RP = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ClientSettings = require(RP:WaitForChild("Module"):WaitForChild("ClientSettings"))
local ModelVFX = require(RP:WaitForChild("Module"):WaitForChild("ModelVFX"))

local VFXHandler = {}
local modelVfxEnabled = ClientSettings:GetToggle("ModelVFXEnabled")

local function refreshWorkspaceModels()
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("Model") and (descendant:FindFirstChild("VfxInstance") or descendant:GetAttribute("AuraSlotsJson")) then
			ModelVFX.RefreshModelFromAttributes(descendant, modelVfxEnabled)
		end
	end
end

ClientSettings:ObserveToggle("ModelVFXEnabled", function(value)
	modelVfxEnabled = value == true
	task.defer(refreshWorkspaceModels)
end)

task.defer(refreshWorkspaceModels)

function VFXHandler:Init(player, ...)
	local halls = { ... }
	local clientType = halls[1]

	if clientType == "Aura" then
		local auraList = halls[2]
		local model = halls[3]
		if not model then
			return
		end

		if not modelVfxEnabled then
			ModelVFX.ClearAura(model)
			return
		end

		ModelVFX.ApplyAuraList(model, auraList)
	end
end

return VFXHandler
