local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GlobalEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("RemoteEvents"):WaitForChild("GlobaleEvent")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local LuckServer = ServerScriptService:WaitForChild("Server"):WaitForChild("LuckServer")

local ServerLuckManager = {}
local serverLuckConfig = GameConfig.ServerLuck

local MAP_MUTATION_LUCK_ATTRIBUTE = serverLuckConfig.MapMutationLuckAttribute
local MAP_MUTATION_TIME_ATTRIBUTE = serverLuckConfig.MapMutationTimeAttribute
local DEFAULT_BASE_MULTIPLIER = serverLuckConfig.DefaultBaseMultiplier
local MAP_STACK_BONUS_FACTOR = serverLuckConfig.MapStackBonusFactor

local initialized = false
local mapMutationExpiredCallback = nil

local function clampTime(value)
	value = tonumber(value) or 0
	if value <= 0 then
		return 0
	end

	return math.max(0, math.floor(value))
end

local function clampMultiplier(value)
	value = tonumber(value) or DEFAULT_BASE_MULTIPLIER
	if value < DEFAULT_BASE_MULTIPLIER then
		return DEFAULT_BASE_MULTIPLIER
	end

	return value
end

local function formatMultiplier(value)
	local formatted = string.format("%.2f", tonumber(value) or DEFAULT_BASE_MULTIPLIER)
	local cleaned = formatted:gsub("%.?0+$", "")
	return cleaned
end

local function setLuckTime(value)
	LuckServer:SetAttribute("Time", clampTime(value))
end

local function setMapMutationTime(value)
	LuckServer:SetAttribute(MAP_MUTATION_TIME_ATTRIBUTE, clampTime(value))
end

local function setMapMutationMultiplier(value)
	LuckServer:SetAttribute(MAP_MUTATION_LUCK_ATTRIBUTE, clampMultiplier(value))
end

local function getBaseTime()
	return clampTime(LuckServer:GetAttribute("Time"))
end

local function getMapMutationTime()
	return clampTime(LuckServer:GetAttribute(MAP_MUTATION_TIME_ATTRIBUTE))
end

local function normalizeBaseState()
	local baseTime = getBaseTime()
	local baseMultiplier = clampMultiplier(LuckServer.Value)

	if baseTime <= 0 then
		if baseMultiplier ~= DEFAULT_BASE_MULTIPLIER then
			LuckServer.Value = DEFAULT_BASE_MULTIPLIER
		end
		if LuckServer:GetAttribute("Time") ~= 0 then
			setLuckTime(0)
		end
		return DEFAULT_BASE_MULTIPLIER, 0
	end

	if baseMultiplier ~= LuckServer.Value then
		LuckServer.Value = baseMultiplier
	end

	return baseMultiplier, baseTime
end

local function normalizeMapMutationState()
	local mapTime = getMapMutationTime()
	local mapMultiplier = clampMultiplier(LuckServer:GetAttribute(MAP_MUTATION_LUCK_ATTRIBUTE))

	if mapTime <= 0 then
		if mapMultiplier ~= DEFAULT_BASE_MULTIPLIER then
			setMapMutationMultiplier(DEFAULT_BASE_MULTIPLIER)
		end
		if LuckServer:GetAttribute(MAP_MUTATION_TIME_ATTRIBUTE) ~= 0 then
			setMapMutationTime(0)
		end
		return DEFAULT_BASE_MULTIPLIER, 0
	end

	if mapMultiplier ~= (LuckServer:GetAttribute(MAP_MUTATION_LUCK_ATTRIBUTE) or DEFAULT_BASE_MULTIPLIER) then
		setMapMutationMultiplier(mapMultiplier)
	end

	return mapMultiplier, mapTime
end

local function getCurrentState()
	local baseMultiplier, baseTime = normalizeBaseState()
	local mapMultiplier, mapTime = normalizeMapMutationState()

	return {
		BaseMultiplier = baseMultiplier,
		BaseTime = baseTime,
		MapMultiplier = mapMultiplier,
		MapTime = mapTime,
	}
end

local function getEffectiveMultiplierFromState(state)
	if state.MapMultiplier <= DEFAULT_BASE_MULTIPLIER then
		return state.BaseMultiplier
	end

	if state.BaseMultiplier <= DEFAULT_BASE_MULTIPLIER then
		return state.MapMultiplier
	end

	return state.MapMultiplier + ((state.BaseMultiplier - DEFAULT_BASE_MULTIPLIER) * MAP_STACK_BONUS_FACTOR)
end

local function getNextMultiplierFromState(state)
	local hasBase = state.BaseMultiplier > DEFAULT_BASE_MULTIPLIER and state.BaseTime > 0
	local hasMap = state.MapMultiplier > DEFAULT_BASE_MULTIPLIER and state.MapTime > 0

	if hasBase and hasMap then
		if state.BaseTime < state.MapTime then
			return state.MapMultiplier
		end

		if state.MapTime < state.BaseTime then
			return state.BaseMultiplier
		end

		return DEFAULT_BASE_MULTIPLIER
	end

	if hasMap then
		return DEFAULT_BASE_MULTIPLIER
	end

	if hasBase then
		return DEFAULT_BASE_MULTIPLIER
	end

	return DEFAULT_BASE_MULTIPLIER
end

local function getTimeUntilNextChangeFromState(state)
	local candidates = {}

	if state.BaseMultiplier > DEFAULT_BASE_MULTIPLIER and state.BaseTime > 0 then
		table.insert(candidates, state.BaseTime)
	end

	if state.MapMultiplier > DEFAULT_BASE_MULTIPLIER and state.MapTime > 0 then
		table.insert(candidates, state.MapTime)
	end

	if #candidates == 0 then
		return 0
	end

	table.sort(candidates)
	return candidates[1]
end

local function getDisplayColors(currentMultiplier, nextMultiplier)
	local currentColor = currentMultiplier > DEFAULT_BASE_MULTIPLIER
		and Color3.new(0.333333, 1, 0.498039)
		or Color3.new(1, 1, 1)

	local nextColor = nextMultiplier > DEFAULT_BASE_MULTIPLIER
		and Color3.new(1, 1, 0)
		or Color3.new(1, 1, 1)

	return currentColor, nextColor
end

function ServerLuckManager:RefreshClient(player)
	if not player then
		return
	end

	self:Init()

	local state = getCurrentState()
	local currentMultiplier = getEffectiveMultiplierFromState(state)
	local nextMultiplier = getNextMultiplierFromState(state)
	local timeUntilNextChange = getTimeUntilNextChangeFromState(state)
	local currentColor, nextColor = getDisplayColors(currentMultiplier, nextMultiplier)

	GlobalEvent:FireClient(
		player,
		"ServerLuck",
		`X{formatMultiplier(currentMultiplier)}`,
		`X{formatMultiplier(nextMultiplier)}`,
		currentColor,
		nextColor
	)

	GlobalEvent:FireClient(player, "AddEvent", "LuckServer", timeUntilNextChange, currentMultiplier)
end

function ServerLuckManager:RefreshClients()
	self:Init()

	for _, player in ipairs(Players:GetPlayers()) do
		self:RefreshClient(player)
	end
end

function ServerLuckManager:GetEffectiveMultiplier()
	self:Init()
	return getEffectiveMultiplierFromState(getCurrentState())
end

function ServerLuckManager:GetCurrentMultiplier()
	self:Init()
	return getEffectiveMultiplierFromState(getCurrentState())
end

function ServerLuckManager:GetMapMutationMultiplier()
	self:Init()
	local state = getCurrentState()
	return state.MapMultiplier, state.MapTime
end

function ServerLuckManager:SetMapMutationBoost(multiplier, duration)
	self:Init()

	setMapMutationMultiplier(multiplier)
	setMapMutationTime(duration)
	self:RefreshClients()
end

function ServerLuckManager:ClearMapMutationBoost()
	self:Init()

	setMapMutationMultiplier(DEFAULT_BASE_MULTIPLIER)
	setMapMutationTime(0)
	self:RefreshClients()
end

function ServerLuckManager:ResetAllBoosts()
	self:Init()

	LuckServer.Value = DEFAULT_BASE_MULTIPLIER
	setLuckTime(0)
	setMapMutationMultiplier(DEFAULT_BASE_MULTIPLIER)
	setMapMutationTime(0)
	self:RefreshClients()
end

function ServerLuckManager:SetMapMutationExpiredCallback(callback)
	if callback ~= nil and typeof(callback) ~= "function" then
		error("Map mutation expiry callback must be a function or nil.")
	end

	mapMutationExpiredCallback = callback
end

function ServerLuckManager:Init()
	if initialized then
		return
	end

	initialized = true

	if LuckServer:GetAttribute("Time") == nil then
		setLuckTime(0)
	end

	if LuckServer:GetAttribute(MAP_MUTATION_LUCK_ATTRIBUTE) == nil then
		setMapMutationMultiplier(DEFAULT_BASE_MULTIPLIER)
	end

	if LuckServer:GetAttribute(MAP_MUTATION_TIME_ATTRIBUTE) == nil then
		setMapMutationTime(0)
	end

	normalizeBaseState()
	normalizeMapMutationState()

	task.spawn(function()
		while true do
			task.wait(1)

			local shouldRefreshClients = false
			local baseTimeBefore = getBaseTime()
			local mapTimeBefore = getMapMutationTime()

			if baseTimeBefore > 0 then
				local nextBaseTime = baseTimeBefore - 1
				setLuckTime(nextBaseTime)
				if nextBaseTime <= 0 then
					normalizeBaseState()
					shouldRefreshClients = true
				end
			end

			if mapTimeBefore > 0 then
				local nextMapTime = mapTimeBefore - 1
				setMapMutationTime(nextMapTime)
				if nextMapTime <= 0 then
					normalizeMapMutationState()
					shouldRefreshClients = true

					if mapMutationExpiredCallback then
						task.spawn(mapMutationExpiredCallback)
					end
				end
			end

			if shouldRefreshClients then
				self:RefreshClients()
			end
		end
	end)
end

return ServerLuckManager
