local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local BaseModule = require(ServerStorage.Module.GameHandler.Base)
local BrainrotSelect = require(ServerStorage.Module.BrainrotSelect)
local DataManager = require(ServerStorage.Data.DataManager)
local BrainrotList = require(ServerStorage.List.BrainrotList)
local DiscoDropList = require(ServerStorage.List.DiscoDropList)
local AuraList = require(ServerStorage.List.AuraList)
local MutationModule = require(ServerStorage.Module.RollModule.Mutation)
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local CommandUtil = require(game.ServerScriptService.Cmdr.CommandUtil)

local DiscoModeManager = {}
local discoConfig = GameConfig.Disco

local DISCO_RUNTIME_FOLDER = discoConfig.RuntimeFolderName
local DISCO_BALL_NAME = discoConfig.BallName
local DISCO_RIG_PREFIX = discoConfig.RigPrefix
local DISCO_TRUSS_SPOTLIGHT_NAME = "Truss with spotlight"
local DISCO_BALL_ROTATION_SPEED = math.rad(discoConfig.BallRotationSpeedDegrees)
local DISCO_RIG_RETRY_INTERVAL = discoConfig.RigRetryInterval
local DISCO_FALL_HEIGHT = discoConfig.FallHeight
local DISCO_DROP_RADIUS_SCALE = discoConfig.DropRadiusScale
local DISCO_DROP_RADIUS_MIN = discoConfig.DropRadiusMin
local DISCO_DROP_RADIUS_MAX = discoConfig.DropRadiusMax
local DISCO_DROP_FALL_TIME_MIN = discoConfig.DropFallTimeMin
local DISCO_DROP_FALL_TIME_MAX = discoConfig.DropFallTimeMax
local DISCO_DROP_INTERVAL_MIN = discoConfig.DropIntervalMin
local DISCO_DROP_INTERVAL_MAX = discoConfig.DropIntervalMax
local DISCO_MAX_ACTIVE_DROPS = discoConfig.MaxActiveDrops
local DISCO_DROP_LIFETIME = discoConfig.DropLifetime
local DISCO_SLOTS = discoConfig.SlotWeights
local ALLOWED_RARITIES = discoConfig.AllowedRarities
local GROUND_NAME_LOOKUP = discoConfig.GroundNames

local activeState = nil
local brainrotPool = nil
local mutationPool = nil
local auraPool = nil
local discoDropListWarningShown = false

local function safeDisconnect(connection)
	if connection then
		connection:Disconnect()
	end
end

local function ensureRuntimeFolder()
	local folder = Workspace:FindFirstChild(DISCO_RUNTIME_FOLDER)
	if folder then
		return folder
	end

	folder = Instance.new("Folder")
	folder.Name = DISCO_RUNTIME_FOLDER
	folder.Parent = Workspace
	return folder
end

local function getRuntimeMutationMap()
	local mapContainer = Workspace:FindFirstChild("Map")
	local runtimeModel = mapContainer and mapContainer:FindFirstChild("MutationMapRuntime")
	if runtimeModel and runtimeModel:IsA("Model") then
		return runtimeModel
	end

	return nil
end

local function getDiscoBallParts(instance)
	local parts = {}
	if not instance then
		return parts
	end

	if instance:IsA("BasePart") then
		table.insert(parts, instance)
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	return parts
end

local function configureDiscoBall(instance)
	for _, part in ipairs(getDiscoBallParts(instance)) do
		part.CanCollide = false
		part.CanTouch = false
		part.Massless = true
	end
end

local function configureDiscoTrussSpotlights(state)
	local runtimeModel = getRuntimeMutationMap()
	if not runtimeModel then
		return false
	end

	local configuredAny = false

	for _, descendant in ipairs(runtimeModel:GetDescendants()) do
		if descendant:IsA("Model") and descendant.Name == DISCO_TRUSS_SPOTLIGHT_NAME then
			for _, part in ipairs(getDiscoBallParts(descendant)) do
				part.CanCollide = false
				part.CanTouch = false
			end

			configuredAny = true
		end
	end

	state.DiscoTrussesConfigured = configuredAny
	return configuredAny
end

local function getDropAreaFromDiscoBall(runtimeModel)
	local discoBall = runtimeModel and runtimeModel:FindFirstChild(DISCO_BALL_NAME, true)
	if not discoBall then
		return nil
	end

	local centerPosition = nil
	local radius = DISCO_DROP_RADIUS_MIN
	local ballHeight = 0

	if discoBall:IsA("Model") then
		local pivotSuccess, pivot = pcall(function()
			return discoBall:GetPivot()
		end)
		local boundsSuccess, _, size = pcall(function()
			return discoBall:GetBoundingBox()
		end)

		if pivotSuccess then
			centerPosition = pivot.Position
		end

		if boundsSuccess then
			ballHeight = size.Y
			radius = math.clamp(
				math.floor((math.max(size.X, size.Z) * 3) + 0.5),
				DISCO_DROP_RADIUS_MIN,
				DISCO_DROP_RADIUS_MAX
			)
		end
	elseif discoBall:IsA("BasePart") then
		centerPosition = discoBall.Position
		ballHeight = discoBall.Size.Y
		radius = math.clamp(
			math.floor((math.max(discoBall.Size.X, discoBall.Size.Z) * 3) + 0.5),
			DISCO_DROP_RADIUS_MIN,
			DISCO_DROP_RADIUS_MAX
		)
	end

	if not centerPosition then
		return nil
	end

	local spawnYOffset = math.clamp(
		math.max(ballHeight * 1.5, 12),
		12,
		math.max(18, DISCO_FALL_HEIGHT * 0.3)
	)

	return {
		CenterPosition = centerPosition,
		Radius = radius,
		SpawnY = centerPosition.Y + spawnYOffset,
	}
end

local function stopDiscoRigAnimations(state)
	for _, track in ipairs(state.DiscoRigTracks or {}) do
		pcall(function()
			track:Stop(0.2)
		end)
		pcall(function()
			track:Destroy()
		end)
	end

	table.clear(state.DiscoRigTracks)
end

local function startDiscoRigAnimations(state)
	local runtimeModel = getRuntimeMutationMap()
	if not runtimeModel then
		state.NextDiscoRigRetryAt = os.clock() + DISCO_RIG_RETRY_INTERVAL
		return
	end

	configureDiscoTrussSpotlights(state)

	stopDiscoRigAnimations(state)

	for _, descendant in ipairs(runtimeModel:GetDescendants()) do
		if descendant:IsA("Model") and string.sub(descendant.Name, 1, #DISCO_RIG_PREFIX) == DISCO_RIG_PREFIX then
			local humanoid = descendant:FindFirstChildOfClass("Humanoid")
			local animation = descendant:FindFirstChildWhichIsA("Animation", true)
			if humanoid and animation then
				local animator = humanoid:FindFirstChildOfClass("Animator")
				if not animator then
					animator = Instance.new("Animator")
					animator.Parent = humanoid
				end

				local success, track = pcall(function()
					return animator:LoadAnimation(animation)
				end)
				if success and track then
					track.Looped = true

					local settings = descendant:FindFirstChild("Settings")
					local speedValue = settings and settings:FindFirstChild("Speed")
					if speedValue and speedValue:IsA("NumberValue") then
						track:AdjustSpeed(speedValue.Value)
					end

					track:Play(0.1)
					table.insert(state.DiscoRigTracks, track)
				end
			end
		end
	end

	if #state.DiscoRigTracks == 0 then
		state.NextDiscoRigRetryAt = os.clock() + DISCO_RIG_RETRY_INTERVAL
	else
		state.NextDiscoRigRetryAt = 0
	end
end

local function normalizeLookupName(name)
	return string.lower((name or "")):gsub("%s+", "")
end

local function isNamedGroundPart(part)
	return GROUND_NAME_LOOKUP[normalizeLookupName(part and part.Name)] == true
end

local function collectGroundParts()
	local runtimeModel = getRuntimeMutationMap()
	if not runtimeModel then
		return {}
	end

	local namedGroundParts = {}
	local fallbackParts = {}
	local runtimeBottomY = nil
	local minSurfaceArea = 64

	local success, runtimeCFrame, runtimeSize = pcall(function()
		return runtimeModel:GetBoundingBox()
	end)
	if success then
		runtimeBottomY = runtimeCFrame.Position.Y - (runtimeSize.Y / 2)
		minSurfaceArea = math.max(64, (math.min(runtimeSize.X, runtimeSize.Z) ^ 2) * 0.02)
	end

	for _, descendant in ipairs(runtimeModel:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.CanQuery then
			if isNamedGroundPart(descendant) then
				table.insert(namedGroundParts, descendant)
			elseif descendant.Anchored then
				local topY = descendant.Position.Y + (descendant.Size.Y / 2)
				local surfaceArea = descendant.Size.X * descendant.Size.Z
				local isLowSurface = runtimeBottomY == nil or topY <= (runtimeBottomY + 20)
				if isLowSurface and surfaceArea >= minSurfaceArea then
					table.insert(fallbackParts, descendant)
				end
			end
		end
	end

	if #namedGroundParts > 0 then
		return namedGroundParts
	end

	table.sort(fallbackParts, function(left, right)
		local leftArea = left.Size.X * left.Size.Z
		local rightArea = right.Size.X * right.Size.Z
		if leftArea == rightArea then
			return (left.Position.Y + (left.Size.Y / 2)) < (right.Position.Y + (right.Size.Y / 2))
		end

		return leftArea > rightArea
	end)

	local selectedParts = {}
	for index = 1, math.min(6, #fallbackParts) do
		table.insert(selectedParts, fallbackParts[index])
	end

	return selectedParts
end

local function resolveGroundParts(state)
	local groundParts = state.GroundParts
	if groundParts and #groundParts > 0 then
		local hasLivePart = false
		for _, part in ipairs(groundParts) do
			if part and part.Parent then
				hasLivePart = true
				break
			end
		end

		if hasLivePart then
			return groundParts
		end
	end

	groundParts = collectGroundParts()
	state.GroundParts = groundParts
	return groundParts
end

local function resolveDiscoBall(state)
	local cachedBall = state.DiscoBall
	if cachedBall and cachedBall.Parent then
		return cachedBall
	end

	local runtimeModel = getRuntimeMutationMap()
	local discoBall = runtimeModel and runtimeModel:FindFirstChild(DISCO_BALL_NAME, true)
	if discoBall then
		state.DiscoBall = discoBall
		state.DiscoBallConfigured = false
	end

	return discoBall
end

local function rotateDiscoBall(state, deltaTime)
	local discoBall = resolveDiscoBall(state)
	if not discoBall then
		return
	end

	if not state.DiscoBallConfigured then
		configureDiscoBall(discoBall)
		state.DiscoBallConfigured = true
	end

	if not (discoBall:IsA("Model") or discoBall:IsA("BasePart")) then
		return
	end

	local success, pivot = pcall(function()
		return discoBall:GetPivot()
	end)
	if success then
		discoBall:PivotTo(pivot * CFrame.Angles(0, DISCO_BALL_ROTATION_SPEED * deltaTime, 0))
	end
end

local function buildWeightedPool(source, predicate)
	local pool = {}
	local totalWeight = 0

	for name, info in pairs(source) do
		if not predicate or predicate(name, info) then
			local weight = tonumber(info and info.Chance) or 0
			if weight > 0 then
				totalWeight += weight
				table.insert(pool, {
					Name = name,
					Weight = weight,
				})
			end
		end
	end

	table.sort(pool, function(left, right)
		return left.Name < right.Name
	end)

	return pool, totalWeight
end

local function warnDiscoDropListFallback(message)
	if discoDropListWarningShown then
		return
	end

	discoDropListWarningShown = true
	warn("[DiscoDropList] " .. message)
end

local function buildConfiguredDiscoDropPool()
	local mergedWeights = {}
	local hasEntries = false

	for index, entry in ipairs(DiscoDropList) do
		hasEntries = true

		local name = nil
		local weight = 1

		if typeof(entry) == "string" then
			name = entry
		elseif typeof(entry) == "table" then
			name = entry.Name or entry.Brainrot or entry[1]
			weight = tonumber(entry.Weight) or 1
		else
			warnDiscoDropListFallback(`Invalid entry at index {index}; expected a string or table.`)
			continue
		end

		if typeof(name) ~= "string" or name == "" then
			warnDiscoDropListFallback(`Entry {index} is missing a valid brainrot name.`)
			continue
		end

		if not BrainrotList[name] then
			warnDiscoDropListFallback(`Brainrot "{name}" does not exist in BrainrotList.`)
			continue
		end

		if weight <= 0 then
			warnDiscoDropListFallback(`Brainrot "{name}" has an invalid weight ({tostring(weight)}).`)
			continue
		end

		mergedWeights[name] = (mergedWeights[name] or 0) + weight
	end

	local pool = {}
	local totalWeight = 0

	for name, weight in pairs(mergedWeights) do
		totalWeight += weight
		table.insert(pool, {
			Name = name,
			Weight = weight,
		})
	end

	table.sort(pool, function(left, right)
		return left.Name < right.Name
	end)

	return pool, totalWeight, hasEntries
end

local function rollFromPool(pool, totalWeight)
	if not pool or #pool == 0 or not totalWeight or totalWeight <= 0 then
		return nil
	end

	local roll = math.random() * totalWeight
	local current = 0

	for _, entry in ipairs(pool) do
		current += entry.Weight
		if roll <= current then
			return entry.Name
		end
	end

	return pool[#pool].Name
end

local function getBrainrotPool()
	if brainrotPool then
		return brainrotPool.Pool, brainrotPool.TotalWeight
	end

	local pool, totalWeight, hasConfiguredEntries = buildConfiguredDiscoDropPool()

	if #pool == 0 then
		if hasConfiguredEntries then
			warnDiscoDropListFallback("No valid custom disco drop entries found; falling back to AllowedRarities.")
		end

		pool, totalWeight = buildWeightedPool(BrainrotList, function(_, info)
			return info and ALLOWED_RARITIES[info.Rarity] == true
		end)
	end

	brainrotPool = {
		Pool = pool,
		TotalWeight = totalWeight,
	}

	return pool, totalWeight
end

local function getMutationPool()
	if mutationPool then
		return mutationPool.Pool, mutationPool.TotalWeight
	end

	local pool, totalWeight = buildWeightedPool(MutationModule.Mutation, function(name)
		return name ~= "Normal"
	end)

	mutationPool = {
		Pool = pool,
		TotalWeight = totalWeight,
	}

	return pool, totalWeight
end

local function getAuraPool()
	if auraPool then
		return auraPool.Pool, auraPool.TotalWeight
	end

	local pool, totalWeight = buildWeightedPool(AuraList)
	auraPool = {
		Pool = pool,
		TotalWeight = totalWeight,
	}

	return pool, totalWeight
end

local function rollDiscoMutation()
	local pool, totalWeight = getMutationPool()
	return rollFromPool(pool, totalWeight) or "Gold"
end

local function rollAuraName()
	local pool, totalWeight = getAuraPool()
	return rollFromPool(pool, totalWeight) or ""
end

local function rollSlotCount()
	local totalWeight = 0
	for _, info in ipairs(DISCO_SLOTS) do
		totalWeight += info.Weight
	end

	local roll = math.random() * totalWeight
	local current = 0

	for _, info in ipairs(DISCO_SLOTS) do
		current += info.Weight
		if roll <= current then
			return info.Count
		end
	end

	return DISCO_SLOTS[1].Count
end

local function buildAuraSlots(slotCount)
	local slots = BrainrotSelect:GetSlotsTable(slotCount)
	for index = 1, slotCount do
		slots[tostring(index)] = rollAuraName()
	end

	return slots
end

local function updateFuseMutation(data, position, mutation)
	if not (data and data.Fuse and typeof(data.Fuse.Fusing) == "table") then
		return
	end

	for _, item in ipairs(data.Fuse.Fusing) do
		if item and tostring(item.Position) == tostring(position) then
			item.Mutation = mutation
		end
	end
end

local function getDropCount(state)
	local activeCount = 0

	for model in pairs(state.SpawnedDrops) do
		if model and model.Parent then
			activeCount += 1
		else
			state.SpawnedDrops[model] = nil
		end
	end

	return activeCount
end

local function waitForBase(player, timeoutSeconds)
	local deadline = os.clock() + (timeoutSeconds or 10)

	repeat
		local base = BaseModule.GetBase(player)
		if base and base.StockBrainrot then
			return base
		end

		task.wait(0.25)
	until player.Parent ~= Players or os.clock() >= deadline

	return BaseModule.GetBase(player)
end

local function refreshPlayerPositions(player, positions)
	if #positions == 0 then
		return
	end

	CommandUtil.RebuildPositions(player, positions)

	local base = BaseModule.GetBase(player)
	if base then
		base:RefreshExistingBrainrots()
	end

	CommandUtil.RefreshAuraSpinUi(player)
	CommandUtil.RefreshMachineUi(player)
end

local function ensurePlayerBrainrotMutations(player)
	local profile = DataManager:GetProfile(player)
	local data = profile and profile.Data
	if not (data and data.Base and typeof(data.Base.Brainrot) == "table") then
		return 0
	end

	local changedPositions = {}

	for _, brainrot in ipairs(data.Base.Brainrot) do
		if brainrot and brainrot.Name then
			local normalizedMutation = MutationModule:NormalizeName(brainrot.Mutation or "Normal")
			if normalizedMutation == "Normal" then
				local newMutation = rollDiscoMutation()
				brainrot.Mutation = newMutation
				updateFuseMutation(data, brainrot.Position, newMutation)
				DataManager.AddIndex(player, brainrot.Name, newMutation)
				table.insert(changedPositions, tostring(brainrot.Position))
			else
				brainrot.Mutation = normalizedMutation
			end
		end
	end

	refreshPlayerPositions(player, changedPositions)
	return #changedPositions
end

local function getDropArea(fallbackPosition)
	local runtimeModel = getRuntimeMutationMap()
	if runtimeModel and runtimeModel:IsA("Model") then
		local discoBallDropArea = getDropAreaFromDiscoBall(runtimeModel)
		if discoBallDropArea then
			return discoBallDropArea
		end

		local success, runtimeCFrame, runtimeSize = pcall(function()
			return runtimeModel:GetBoundingBox()
		end)
		if success then
			local radius = math.floor(
				math.clamp(
					math.min(runtimeSize.X, runtimeSize.Z) * DISCO_DROP_RADIUS_SCALE,
					DISCO_DROP_RADIUS_MIN,
					DISCO_DROP_RADIUS_MAX
				)
			)

			return {
				CenterPosition = runtimeCFrame.Position,
				Radius = radius,
				SpawnY = runtimeCFrame.Position.Y + DISCO_FALL_HEIGHT,
			}
		end
	end

	return {
		CenterPosition = fallbackPosition or Vector3.zero,
		Radius = 14,
		SpawnY = (fallbackPosition or Vector3.zero).Y + DISCO_FALL_HEIGHT,
	}
end

local function getDropLift(model)
	local candidates = {
		model and model:FindFirstChild("Hitbox", true),
		model and model.PrimaryPart,
		model and model:FindFirstChild("RootPart", true),
		model and model:FindFirstChild("HumanoidRootPart", true),
		model and model:FindFirstChildWhichIsA("BasePart", true),
	}

	for _, candidate in ipairs(candidates) do
		if candidate and candidate:IsA("BasePart") then
			return math.clamp((candidate.Size.Y / 2) + 0.25, 0.9, 2.75)
		end
	end

	local success, _, size = pcall(function()
		return model:GetBoundingBox()
	end)
	if success then
		return math.clamp((size.Y * 0.2) + 0.25, 0.9, 2.75)
	end

	return 1.5
end

local function getDropTargetCFrame(state, model, dropArea)
	local groundParts = resolveGroundParts(state)
	local rayParams = RaycastParams.new()
	if #groundParts > 0 then
		rayParams.FilterType = Enum.RaycastFilterType.Include
		rayParams.FilterDescendantsInstances = groundParts
	else
		local filterList = {
			model,
			ensureRuntimeFolder(),
		}
		local discoBall = resolveDiscoBall(state)
		if discoBall then
			table.insert(filterList, discoBall)
		end

		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = filterList
	end

	local lift = getDropLift(model)
	local rayOriginY = dropArea.SpawnY or (dropArea.CenterPosition.Y + DISCO_FALL_HEIGHT)
	local rayDistance = math.max(DISCO_FALL_HEIGHT * 2, math.abs(rayOriginY - dropArea.CenterPosition.Y) + DISCO_FALL_HEIGHT)

	for _ = 1, 12 do
		local angle = math.random() * math.pi * 2
		local distance = math.sqrt(math.random()) * dropArea.Radius
		local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local origin = Vector3.new(
			dropArea.CenterPosition.X + offset.X,
			rayOriginY,
			dropArea.CenterPosition.Z + offset.Z
		)
		local result = Workspace:Raycast(origin, Vector3.new(0, -rayDistance, 0), rayParams)
		if result then
			local position = result.Position + Vector3.new(0, lift, 0)
			return CFrame.new(position)
		end
	end

	return CFrame.new(dropArea.CenterPosition + Vector3.new(0, lift, 0))
end

local function animateSkyDrop(state, model, targetCFrame)
	local targetPosition = targetCFrame.Position
	local dropArea = state.DropArea
	local startRadius = math.max(8, math.floor(dropArea.Radius * 0.5))
	local startY = dropArea.SpawnY or (targetPosition.Y + DISCO_FALL_HEIGHT)
	local startPosition = targetPosition + Vector3.new(
		math.random(-startRadius, startRadius),
		0,
		math.random(-startRadius, startRadius)
	)
	startPosition = Vector3.new(startPosition.X, startY, startPosition.Z)
	local duration = DISCO_DROP_FALL_TIME_MIN
	if DISCO_DROP_FALL_TIME_MAX > DISCO_DROP_FALL_TIME_MIN then
		duration += math.random() * (DISCO_DROP_FALL_TIME_MAX - DISCO_DROP_FALL_TIME_MIN)
	end

	local startTime = os.clock()
	while state.Active and model.Parent and (os.clock() - startTime) < duration do
		local alpha = math.clamp((os.clock() - startTime) / duration, 0, 1)
		local position = startPosition:Lerp(targetPosition, alpha)
		local yaw = math.rad(360 * 3 * alpha)
		local pitch = math.rad(360 * alpha)
		model:PivotTo(CFrame.new(position) * CFrame.Angles(pitch, yaw, 0))
		RunService.Heartbeat:Wait()
	end

	if state.Active and model.Parent then
		model:PivotTo(targetCFrame)
	end
end

local function scheduleDropExpiry(state, model)
	task.delay(DISCO_DROP_LIFETIME, function()
		if state ~= activeState or not state.Active then
			return
		end

		if state.SpawnedDrops[model] and model and model.Parent then
			model:Destroy()
		end
	end)
end

local function spawnSkyDrop(state)
	if not state.Active or getDropCount(state) >= DISCO_MAX_ACTIVE_DROPS then
		return false
	end

	local pool, totalWeight = getBrainrotPool()
	local brainrotName = rollFromPool(pool, totalWeight)
	if not brainrotName then
		return false
	end

	local mutation = rollDiscoMutation()
	local slotCount = rollSlotCount()
	local slots = buildAuraSlots(slotCount)
	local brainrotData = {
		Name = brainrotName,
		Mutation = mutation,
		Slots = slots,
	}

	local model = BrainrotSelect:GetBrainrot(brainrotName, mutation)
	if not model then
		return false
	end

	model.Parent = ensureRuntimeFolder()
	model:SetAttribute("DiscoDrop", true)
	model:SetAttribute("Owner", nil)
	model:SetAttribute("Position", nil)
	model:SetAttribute("Mutation", mutation)
	model:SetAttribute("Type", "Default")
	model:SetAttribute("Mode", "")
	model:SetAttribute("InPlace", false)

	BrainrotSelect:PrepareDroppedModel(model)
	BrainrotSelect:SetInfoByMode(model, { "Default", "" }, brainrotData)

	state.DropArea = getDropArea(state.DropFallbackPosition)
	local targetCFrame = getDropTargetCFrame(state, model, state.DropArea)
	animateSkyDrop(state, model, targetCFrame)

	if not (state.Active and model.Parent) then
		if model.Parent then
			model:Destroy()
		end
		return false
	end

	local droppedModel = BrainrotSelect:CreateAbandonedDrop(model, brainrotData)
	if not droppedModel then
		return false
	end

	droppedModel:SetAttribute("DiscoDrop", true)
	state.SpawnedDrops[droppedModel] = true

	state.DropConnections[droppedModel] = droppedModel.Destroying:Connect(function()
		state.SpawnedDrops[droppedModel] = nil
		safeDisconnect(state.DropConnections[droppedModel])
		state.DropConnections[droppedModel] = nil
	end)

	scheduleDropExpiry(state, droppedModel)
	return true
end

local function destroyTrackedDrops(state)
	for model in pairs(state.SpawnedDrops) do
		if model and model.Parent then
			model:Destroy()
		end
	end

	for model, connection in pairs(state.DropConnections) do
		safeDisconnect(connection)
		state.DropConnections[model] = nil
	end

	table.clear(state.SpawnedDrops)

	local runtimeFolder = Workspace:FindFirstChild(DISCO_RUNTIME_FOLDER)
	if runtimeFolder then
		for _, child in ipairs(runtimeFolder:GetChildren()) do
			child:Destroy()
		end
	end
end

function DiscoModeManager:IsActive()
	return activeState ~= nil and activeState.Active == true
end

function DiscoModeManager:EnsurePlayerBrainrotMutations(player)
	return ensurePlayerBrainrotMutations(player)
end

function DiscoModeManager:Start(options)
	if self:IsActive() then
		self:Stop()
	end

	local state = {
		Active = true,
		DropArea = nil,
		DropFallbackPosition = options and options.TargetPosition,
		DiscoBall = nil,
		DiscoBallConfigured = false,
		DiscoTrussesConfigured = false,
		DiscoRigTracks = {},
		NextDiscoRigRetryAt = 0,
		GroundParts = {},
		SpawnedDrops = {},
		DropConnections = {},
	}

	activeState = state
	state.DropArea = getDropArea(state.DropFallbackPosition)
	startDiscoRigAnimations(state)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			waitForBase(player, 5)
			if state.Active then
				ensurePlayerBrainrotMutations(player)
			end
		end)
	end

	state.PlayerAddedConnection = Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			waitForBase(player, 12)
			if state.Active then
				ensurePlayerBrainrotMutations(player)
			end
		end)
	end)

	state.DiscoBallConnection = RunService.Heartbeat:Connect(function(deltaTime)
		if not state.Active then
			return
		end

		if not state.DiscoTrussesConfigured then
			configureDiscoTrussSpotlights(state)
		end

		if #state.DiscoRigTracks == 0 and os.clock() >= (state.NextDiscoRigRetryAt or 0) then
			startDiscoRigAnimations(state)
		end

		rotateDiscoBall(state, deltaTime)
	end)

	state.DropLoopThread = task.spawn(function()
		task.wait(4)

		while state.Active do
			pcall(spawnSkyDrop, state)

			local delayTime = DISCO_DROP_INTERVAL_MIN
			if DISCO_DROP_INTERVAL_MAX > DISCO_DROP_INTERVAL_MIN then
				delayTime += math.random() * (DISCO_DROP_INTERVAL_MAX - DISCO_DROP_INTERVAL_MIN)
			end
			task.wait(delayTime)
		end
	end)

	return function()
		if activeState == state then
			DiscoModeManager:Stop()
		else
			state.Active = false
			stopDiscoRigAnimations(state)
			destroyTrackedDrops(state)
			safeDisconnect(state.DiscoBallConnection)
			safeDisconnect(state.PlayerAddedConnection)
		end
	end
end

function DiscoModeManager:Stop()
	local state = activeState
	if not state then
		return
	end

	activeState = nil
	state.Active = false

	stopDiscoRigAnimations(state)
	safeDisconnect(state.DiscoBallConnection)
	safeDisconnect(state.PlayerAddedConnection)
	destroyTrackedDrops(state)

	local runtimeFolder = Workspace:FindFirstChild(DISCO_RUNTIME_FOLDER)
	if runtimeFolder then
		if #runtimeFolder:GetChildren() == 0 then
			runtimeFolder:Destroy()
		end
	end
end

return DiscoModeManager
