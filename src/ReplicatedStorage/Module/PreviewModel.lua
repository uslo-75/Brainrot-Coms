local Players = game:GetService("Players")
local RP = game:GetService("ReplicatedStorage")

local RemoteEvent = require(RP:WaitForChild("MyService"):WaitForChild("Service"):WaitForChild("RemoteEvent"))
local GameConfig = require(RP:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))

local PreviewModel = {}
local player = Players.LocalPlayer
local PREVIEW_TIMEOUT = GameConfig.Preview.ClientTimeout
local PREVIEW_DEBUG = false

local function CreateGeneratedRootPart(model)
	local existingRoot = model:FindFirstChild("GeneratedRootPart")
	if existingRoot and existingRoot:IsA("BasePart") then
		model.PrimaryPart = existingRoot
		return existingRoot
	end

	local pivot
	local success = pcall(function()
		pivot = model:GetPivot()
	end)

	local generatedRoot = Instance.new("Part")
	generatedRoot.Name = "GeneratedRootPart"
	generatedRoot.Size = Vector3.new(1, 1, 1)
	generatedRoot.Transparency = 1
	generatedRoot.CastShadow = false
	generatedRoot.Anchored = false
	generatedRoot.CanCollide = false
	generatedRoot.CanTouch = false
	generatedRoot.CanQuery = false
	generatedRoot.Massless = true
	generatedRoot.CFrame = success and pivot or CFrame.new()
	generatedRoot.Parent = model

	model.PrimaryPart = generatedRoot
	return generatedRoot
end

local function EnsurePrimaryPart(model)
	if not model then
		return nil
	end

	local candidates = {
		model.PrimaryPart,
		model:FindFirstChild("RootPart", true),
		model:FindFirstChild("HumanoidRootPart", true),
		model:FindFirstChild("PrimaryPart", true),
		model:FindFirstChild("Hitbox", true),
		model:FindFirstChild("Head", true),
		model:FindFirstChildWhichIsA("BasePart", true),
	}

	for _, candidate in ipairs(candidates) do
		if candidate
			and candidate:IsA("BasePart")
			and candidate.Name ~= "PromptRoot"
			and candidate.Name ~= "SlotPromptRoot"
			and candidate.Name ~= "BrainrotPromptRoot"
			and candidate.Name ~= "GeneratedRootPart"
		then
			model.PrimaryPart = candidate
			return candidate
		end
	end

	return CreateGeneratedRootPart(model)
end

local function previewDebug(previewKey, ...)
	if PREVIEW_DEBUG and previewKey and previewKey:match("^Index_") then
		warn("[IndexDebug][ClientPreview]", previewKey, ...)
	end
end

local function getRootFolder()
	return RP:WaitForChild("PreviewCache", 5)
end

local function getPlayerFolder()
	local rootFolder = getRootFolder()
	if not rootFolder then
		return nil
	end

	return rootFolder:FindFirstChild(tostring(player.UserId)) or rootFolder:WaitForChild(tostring(player.UserId), 5)
end

function PreviewModel:GetModel(previewKey, name, mutation)
	if not previewKey or not name then
		return nil
	end

	local success = RemoteEvent:InvokeServer("GetInfo", "PreviewBrainrot", previewKey, name, mutation or "Normal")
	if not success then
		previewDebug(previewKey, "server rejected preview", "name=", name, "mutation=", mutation or "Normal")
		return nil
	end

	local playerFolder = getPlayerFolder()
	if not playerFolder then
		previewDebug(previewKey, "player preview folder missing")
		return nil
	end

	local previewFolder = playerFolder:FindFirstChild(previewKey) or playerFolder:WaitForChild(previewKey, PREVIEW_TIMEOUT)
	if not previewFolder then
		previewDebug(previewKey, "preview folder missing after wait")
		return nil
	end

	local deadline = os.clock() + PREVIEW_TIMEOUT
	local model = previewFolder:FindFirstChildWhichIsA("Model") or previewFolder:FindFirstChild(name)

	while not model and os.clock() < deadline do
		task.wait()
		model = previewFolder:FindFirstChildWhichIsA("Model") or previewFolder:FindFirstChild(name)
	end

	if not model then
		previewDebug(previewKey, "model missing inside preview folder", "folder=", previewFolder:GetFullName())
		return nil
	end

	local clone = model:Clone()
	EnsurePrimaryPart(clone)
	return clone
end

function PreviewModel:Clear(previewKey)
	if not previewKey or previewKey == "" then
		return
	end

	RemoteEvent:InvokeServer("GetInfo", "ClearPreviewBrainrot", previewKey)
end

return PreviewModel
