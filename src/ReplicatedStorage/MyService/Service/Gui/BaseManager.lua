local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local BaseManager = {}
BaseManager.__index = BaseManager

local trackedBases = {}
local updateConnection = nil
local updateAccumulator = 0
local UPDATE_INTERVAL = 0.25

local function setBaseLabel(inst: Instance, text: string)
	local info = inst and inst:FindFirstChild("Info")
	local label = info and info:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

local function refreshBase(inst: Instance)
	if not inst or not inst:IsDescendantOf(game) then
		trackedBases[inst] = nil
		return
	end

	local unlockTime = inst:GetAttribute("UnlockTime")
	if not unlockTime then
		setBaseLabel(inst, "")
		return
	end

	local remaining = math.max(0, unlockTime - os.time())
	setBaseLabel(inst, tostring(remaining) .. " s")
end

local function stopUpdateLoopIfIdle()
	if next(trackedBases) ~= nil or not updateConnection then
		return
	end

	updateConnection:Disconnect()
	updateConnection = nil
	updateAccumulator = 0
end

local function ensureUpdateLoop()
	if updateConnection then
		return
	end

	updateConnection = RunService.Heartbeat:Connect(function(dt)
		updateAccumulator += dt
		if updateAccumulator < UPDATE_INTERVAL then
			return
		end

		updateAccumulator = 0

		for inst in pairs(trackedBases) do
			if not inst:IsDescendantOf(game) or not CollectionService:HasTag(inst, "TimeLockedBase") then
				trackedBases[inst] = nil
				setBaseLabel(inst, "")
			else
				refreshBase(inst)
			end
		end

		stopUpdateLoopIfIdle()
	end)
end

local function startTracking(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end

	trackedBases[inst] = true
	refreshBase(inst)
	ensureUpdateLoop()
end

local function stopTracking(inst: Instance)
	trackedBases[inst] = nil
	setBaseLabel(inst, "")
	stopUpdateLoopIfIdle()
end

function BaseManager:SetTag()
	for _, inst in ipairs(CollectionService:GetTagged("TimeLockedBase")) do
		startTracking(inst)
	end

	CollectionService:GetInstanceAddedSignal("TimeLockedBase"):Connect(startTracking)
	CollectionService:GetInstanceRemovedSignal("TimeLockedBase"):Connect(stopTracking)
end

function BaseManager:Init()
	self:SetTag()
end

return BaseManager
