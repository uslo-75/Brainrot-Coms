local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local MutationModule = require(ServerStorage.Module.RollModule.Mutation)
local DiscoModeManager = require(ServerStorage.Module.DiscoModeManager)
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local ServerLuckManager = require(ServerStorage.Module.ServerLuckManager)

local MapMutationManager = {}
local mapMutationConfig = GameConfig.MapMutation
local mapPositions = mapMutationConfig.Positions
local adminAbusePositions = mapMutationConfig.AdminAbusePositions

local GlobalEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("RemoteEvents"):WaitForChild("GlobaleEvent")
local MAP_MUTATION_SERVER_LUCK_MULTIPLIER = mapMutationConfig.ServerLuckMultiplier
local MAP_MUTATION_SERVER_LUCK_DURATION = mapMutationConfig.ServerLuckDuration
local MAP_TRANSITION_DELAY = mapMutationConfig.TransitionDelay
local MAP_TRANSITION_SETTLE_DELAY = math.max(MAP_TRANSITION_DELAY + 0.65, 0.75)

local PROTECTED_MAP_CHILDREN = {
	Base = true,
	Shop = true,
	ToolShop = true,
	RobuxShop = true,
	Fusion = true,
	AuraSpin = true,
}

local PROTECTED_NAME_PATTERNS = {
	"Shop",
	"Fusion",
	"AuraSpin",
}

local LIGHTING_PROPERTIES = {
	"Ambient",
	"OutdoorAmbient",
	"Brightness",
	"ColorShift_Top",
	"ColorShift_Bottom",
	"EnvironmentDiffuseScale",
	"EnvironmentSpecularScale",
	"ExposureCompensation",
}

local LIGHTING_CONFIGURATION_SUFFIXES = {
	Ambient = "Ambient",
	OutdoorAmbient = "OutdoorAmbient",
	Brightness = "Brightness",
	ColorShiftTop = "ColorShift_Top",
	ColorShiftBottom = "ColorShift_Bottom",
	EnvironmentDiffuseScale = "EnvironmentDiffuseScale",
	EnvironmentSpecularScale = "EnvironmentSpecularScale",
	ExposureCompensation = "ExposureCompensation",
	ColorShift_Top = "ColorShift_Top",
	ColorShift_Bottom = "ColorShift_Bottom",
	Exposure_Compensation = "ExposureCompensation",
}

local LIGHTING_EFFECT_CLASSES = {
	Atmosphere = true,
	BloomEffect = true,
	BlurEffect = true,
	ColorCorrectionEffect = true,
	DepthOfFieldEffect = true,
	Sky = true,
	SunRaysEffect = true,
}

local MAP_DEFINITIONS = {
	Normal = {
		DisplayName = "Normal",
	},
	BubbleGum = {
		DisplayName = "BubbleGum",
		MapName = "BubbleGum Map",
		LightingName = "BubbleGum Map",
		TargetPosition = mapPositions.BubbleGum,
	},
	Electric = {
		DisplayName = "Electric",
		MapName = "Electric Map",
		LightingName = "Electrical Map",
		TargetPosition = mapPositions.Electric,
	},
	Freeze = {
		DisplayName = "Freeze",
		MapName = "Ice Map",
		LightingName = "Ice Map",
		TargetPosition = mapPositions.Freeze,
	},
	Solar = {
		DisplayName = "Solar",
		MapName = "Solar Map",
		LightingName = "Solar Map",
		TargetPosition = mapPositions.Solar,
	},
	Spectral = {
		DisplayName = "Spectral",
		MapName = "Spectral Map",
		LightingName = "Spectral Map",
		TargetPosition = mapPositions.Spectral,
	},
	Volcan = {
		DisplayName = "Volcan",
		MapName = "Volcano Map",
		LightingName = "Volcano Map",
		TargetPosition = mapPositions.Volcan,
	},
}

local ADMIN_ABUSE_DEFINITIONS = {
	Disco = {
		DisplayName = "Disco",
		MapName = "Disco Map",
		LightingName = "Disco Map",
		TargetPosition = adminAbusePositions.Disco,
		SpawnLocationBehavior = "Disable",
		OnEnter = function(definition)
			return DiscoModeManager:Start({
				TargetPosition = definition.TargetPosition,
			})
		end,
	},
}

local originalMapChildren = {}
local originalLightingChildren = {}
local originalLightingProperties = {}
local originalMapPivot = nil
local currentBaseReferenceCFrame = nil
local hiddenOriginalMaps = nil
local initialized = false
local activeMutation = "Normal"
local activeModeCleanup = nil

local function getActiveAdminAbuse(modeName)
	if modeName and ADMIN_ABUSE_DEFINITIONS[modeName] then
		return modeName
	end

	return ""
end

local function safeClone(instance)
	if not instance then
		return nil
	end

	local previousArchivable = instance.Archivable
	instance.Archivable = true
	local clone = instance:Clone()
	instance.Archivable = previousArchivable

	return clone
end

local function clearArray(list)
	for index = #list, 1, -1 do
		list[index] = nil
	end
end

local function getCharacterAnchorPart(character)
	if not character then
		return nil
	end

	local candidates = {
		character.PrimaryPart,
		character:FindFirstChild("HumanoidRootPart"),
		character:FindFirstChild("UpperTorso"),
		character:FindFirstChild("Torso"),
		character:FindFirstChildWhichIsA("BasePart"),
	}

	for _, candidate in ipairs(candidates) do
		if candidate and candidate:IsA("BasePart") then
			return candidate
		end
	end

	return nil
end

local function stopCharacterMotion(part)
	if not (part and part:IsA("BasePart")) then
		return
	end

	part.AssemblyLinearVelocity = Vector3.zero
	part.AssemblyAngularVelocity = Vector3.zero
end

local function anchorCharacterForTransition(lockState, character)
	if not (lockState and character) or lockState.CharacterStates[character] then
		return
	end

	local anchorPart = getCharacterAnchorPart(character)
	if not anchorPart then
		return
	end

	stopCharacterMotion(anchorPart)
	lockState.CharacterStates[character] = {
		Part = anchorPart,
		WasAnchored = anchorPart.Anchored,
	}
	anchorPart.Anchored = true
end

local function beginTransitionCharacterLock()
	local lockState = {
		CharacterStates = {},
		Connections = {},
	}

	local function bindPlayer(player)
		table.insert(lockState.Connections, player.CharacterAdded:Connect(function(character)
			anchorCharacterForTransition(lockState, character)
		end))

		if player.Character then
			anchorCharacterForTransition(lockState, player.Character)
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		bindPlayer(player)
	end

	table.insert(lockState.Connections, Players.PlayerAdded:Connect(bindPlayer))

	return lockState
end

local function releaseTransitionCharacterLock(lockState)
	if not lockState then
		return
	end

	for character, state in pairs(lockState.CharacterStates) do
		local anchorPart = state.Part
		if anchorPart and anchorPart.Parent then
			stopCharacterMotion(anchorPart)
			anchorPart.Anchored = state.WasAnchored == true
		end

		lockState.CharacterStates[character] = nil
	end

	for _, connection in ipairs(lockState.Connections) do
		connection:Disconnect()
	end

	clearArray(lockState.Connections)
end

local function runMapTransition(callback)
	local lockState = beginTransitionCharacterLock()

	GlobalEvent:FireAllClients("MapTransition")
	task.wait(MAP_TRANSITION_DELAY)

	local ok, resultA, resultB = pcall(callback)
	task.wait(MAP_TRANSITION_SETTLE_DELAY)
	releaseTransitionCharacterLock(lockState)

	if not ok then
		return false, tostring(resultA)
	end

	return resultA, resultB
end

local function getMapContainer()
	return Workspace:WaitForChild("Map")
end

local function getMapLibrary()
	return ServerStorage:WaitForChild("MutationsMap")
end

local function getLightingLibrary()
	return ServerStorage:WaitForChild("LightningFolder")
end

local function getHiddenMapContainer()
	local folder = ServerStorage:FindFirstChild("__HiddenMapMutation")
	if folder then
		return folder
	end

	folder = Instance.new("Folder")
	folder.Name = "__HiddenMapMutation"
	folder.Parent = ServerStorage

	return folder
end

local function getOriginalMapsContainer()
	return Workspace:FindFirstChild("Maps") or getMapContainer():FindFirstChild("Maps")
end

local function getLightingPropertyFromValueName(valueName)
	for suffix, propertyName in pairs(LIGHTING_CONFIGURATION_SUFFIXES) do
		if string.match(valueName, suffix .. "$") then
			return propertyName
		end
	end

	return nil
end

local function isProtectedMapChild(child)
	if not child then
		return false
	end

	if PROTECTED_MAP_CHILDREN[child.Name] then
		return true
	end

	for _, pattern in ipairs(PROTECTED_NAME_PATTERNS) do
		if string.find(child.Name, pattern, 1, true) ~= nil then
			return true
		end
	end

	return false
end

local function hasPivotDescendant(instance)
	if instance:IsA("BasePart") or instance:IsA("Model") then
		return true
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") or descendant:IsA("Model") then
			return true
		end
	end

	return false
end

local function buildPivotModel(children, parent)
	local pivotModel = Instance.new("Model")
	pivotModel.Name = "__MapMutationPivot"
	pivotModel.Parent = parent

	local hasPivotContent = false

	for _, child in ipairs(children) do
		local clone = safeClone(child)
		if clone then
			clone.Parent = pivotModel
			hasPivotContent = hasPivotContent or hasPivotDescendant(clone)
		end
	end

	if not hasPivotContent then
		pivotModel:Destroy()
		return nil
	end

	return pivotModel
end

local function getChildrenPivot(children)
	local pivotModel = buildPivotModel(children, ServerStorage)
	if not pivotModel then
		return nil
	end

	local success, pivot = pcall(function()
		return pivotModel:GetPivot()
	end)

	pivotModel:Destroy()

	if success then
		return pivot
	end

	return nil
end

local function applyRuntimeSpawnLocationBehavior(runtimeModel, behavior)
	if not runtimeModel then
		return
	end

	for _, descendant in ipairs(runtimeModel:GetDescendants()) do
		if descendant:IsA("SpawnLocation") then
			if behavior == "Disable" then
				descendant.Enabled = false
			else
				descendant:Destroy()
			end
		end
	end
end

local function getBaseReferenceCFrame(baseFolder)
	if not baseFolder then
		return nil
	end

	local orderedBaseFolders = {}

	for _, child in ipairs(baseFolder:GetChildren()) do
		if child:IsA("Folder") then
			table.insert(orderedBaseFolders, child)
		end
	end

	table.sort(orderedBaseFolders, function(left, right)
		local leftNumber = tonumber(left.Name) or math.huge
		local rightNumber = tonumber(right.Name) or math.huge
		if leftNumber == rightNumber then
			return left.Name < right.Name
		end

		return leftNumber < rightNumber
	end)

	for _, folder in ipairs(orderedBaseFolders) do
		local spawn = folder:FindFirstChild("Spawn")
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame
		end
	end

	local recursiveSpawn = baseFolder:FindFirstChild("Spawn", true)
	if recursiveSpawn and recursiveSpawn:IsA("BasePart") then
		return recursiveSpawn.CFrame
	end

	local fallbackPart = baseFolder:FindFirstChildWhichIsA("BasePart", true)
	if fallbackPart then
		return fallbackPart.CFrame
	end

	return nil
end

local function backupOriginalMap()
	clearArray(originalMapChildren)

	local mapContainer = getMapContainer()
	local pivotCandidates = {}

	for _, child in ipairs(mapContainer:GetChildren()) do
		if not isProtectedMapChild(child) then
			local clone = safeClone(child)
			if clone then
				table.insert(originalMapChildren, clone)
			end
			table.insert(pivotCandidates, child)
		end
	end

	currentBaseReferenceCFrame = getBaseReferenceCFrame(mapContainer:FindFirstChild("Base"))
	originalMapPivot = getChildrenPivot(pivotCandidates) or currentBaseReferenceCFrame
end

local function hideOriginalMaps()
	local mapsFolder = getOriginalMapsContainer()
	if not mapsFolder then
		return
	end

	hiddenOriginalMaps = mapsFolder
	mapsFolder.Parent = getHiddenMapContainer()
end

local function showOriginalMaps()
	local mapsFolder = getOriginalMapsContainer() or hiddenOriginalMaps or getHiddenMapContainer():FindFirstChild("Maps")
	if not mapsFolder then
		return
	end

	mapsFolder.Parent = Workspace
	hiddenOriginalMaps = mapsFolder
end

local function backupOriginalLighting()
	clearArray(originalLightingChildren)

	for _, propertyName in ipairs(LIGHTING_PROPERTIES) do
		originalLightingProperties[propertyName] = Lighting[propertyName]
	end

	for _, child in ipairs(Lighting:GetChildren()) do
		if LIGHTING_EFFECT_CLASSES[child.ClassName] then
			local clone = safeClone(child)
			if clone then
				table.insert(originalLightingChildren, clone)
			end
		end
	end
end

local function applyMapChildren(children, sourceBaseFolder, shouldAlignToCurrentBase, extraOffset, targetPosition)
	local mapContainer = getMapContainer()
	local pendingRemoval = {}

	if shouldAlignToCurrentBase == true then
		hideOriginalMaps()
	end

	for _, child in ipairs(mapContainer:GetChildren()) do
		if not isProtectedMapChild(child) then
			table.insert(pendingRemoval, child)
		end
	end

	local pivotModel = buildPivotModel(children, ServerStorage)

	if pivotModel then
		if shouldAlignToCurrentBase == true then
			local sourceBaseReferenceCFrame = getBaseReferenceCFrame(sourceBaseFolder)
			if currentBaseReferenceCFrame and sourceBaseReferenceCFrame then
				pivotModel:TranslateBy(currentBaseReferenceCFrame.Position - sourceBaseReferenceCFrame.Position + (extraOffset or Vector3.zero))
			elseif originalMapPivot then
				pivotModel:PivotTo(originalMapPivot)
				if extraOffset then
					pivotModel:TranslateBy(extraOffset)
				end
			end
		end

		if targetPosition then
			local currentPivot = pivotModel:GetPivot()
			local rotationOnly = currentPivot - currentPivot.Position
			pivotModel:PivotTo(CFrame.new(targetPosition) * rotationOnly)
		end

		pivotModel.Name = "MutationMapRuntime"
		pivotModel.Parent = mapContainer
	end

	for _, child in ipairs(pendingRemoval) do
		if child.Parent == mapContainer then
			child:Destroy()
		end
	end

	return pivotModel
end

local function restoreOriginalMap()
	applyMapChildren(originalMapChildren, nil, false)
	showOriginalMaps()
end

local function applyMapTemplate(folderName, extraOffset, targetPosition, spawnLocationBehavior)
	local mapTemplate = getMapLibrary():FindFirstChild(folderName)
	if not mapTemplate then
		return false, `Map "{folderName}" introuvable dans ServerStorage.MutationsMap.`
	end

	local childrenToClone = {}

	for _, child in ipairs(mapTemplate:GetChildren()) do
		if not isProtectedMapChild(child) then
			table.insert(childrenToClone, child)
		end
	end

	local runtimeModel = applyMapChildren(childrenToClone, mapTemplate:FindFirstChild("Base"), true, extraOffset, targetPosition)
	applyRuntimeSpawnLocationBehavior(runtimeModel, spawnLocationBehavior)
	return true
end

local function clearLightingEffects()
	for _, child in ipairs(Lighting:GetChildren()) do
		if LIGHTING_EFFECT_CLASSES[child.ClassName] then
			child:Destroy()
		end
	end
end

local function applyLightingProperties(propertyTable)
	for propertyName, value in pairs(propertyTable) do
		Lighting[propertyName] = value
	end
end

local function restoreOriginalLighting()
	clearLightingEffects()
	applyLightingProperties(originalLightingProperties)

	for _, child in ipairs(originalLightingChildren) do
		local clone = safeClone(child)
		if clone then
			clone.Parent = Lighting
		end
	end
end

local function applyLightingTemplate(folderName)
	local lightingFolder = getLightingLibrary():FindFirstChild(folderName)
	if not lightingFolder then
		return false, `Lighting "{folderName}" introuvable dans ServerStorage.LightningFolder.`
	end

	local propertiesToApply = {}
	local lightingChildren = {}

	for _, child in ipairs(lightingFolder:GetChildren()) do
		if child:IsA("Configuration") then
			for _, valueObject in ipairs(child:GetChildren()) do
				local propertyName = getLightingPropertyFromValueName(valueObject.Name)
				if propertyName and valueObject:IsA("ValueBase") then
					propertiesToApply[propertyName] = valueObject.Value
				end
			end
		elseif LIGHTING_EFFECT_CLASSES[child.ClassName] then
			table.insert(lightingChildren, child)
		end
	end

	clearLightingEffects()
	applyLightingProperties(propertiesToApply)

	for _, child in ipairs(lightingChildren) do
		local clone = safeClone(child)
		if clone then
			clone.Parent = Lighting
		end
	end

	return true
end

local function setActiveMutation(mutationName)
	activeMutation = mutationName
	Workspace:SetAttribute("ActiveMapMutation", mutationName)
	Lighting:SetAttribute("ActiveMapMutation", mutationName)
	local activeAdminAbuse = getActiveAdminAbuse(mutationName)
	Workspace:SetAttribute("ActiveAdminAbuse", activeAdminAbuse)
	Lighting:SetAttribute("ActiveAdminAbuse", activeAdminAbuse)
end

local function cleanupActiveMode()
	if activeModeCleanup then
		local cleanup = activeModeCleanup
		activeModeCleanup = nil
		pcall(cleanup)
	end
end

local function restoreEnvironment()
	cleanupActiveMode()
	restoreOriginalMap()
	restoreOriginalLighting()
	setActiveMutation("Normal")
end

local function clearLuckBoost(clearAllLuckBoosts)
	if clearAllLuckBoosts == true then
		ServerLuckManager:ResetAllBoosts()
	else
		ServerLuckManager:ClearMapMutationBoost()
	end
end

local function validateDefinition(definition, modeName)
	if not definition then
		return false, `Definition de mode introuvable pour "{tostring(modeName)}".`
	end

	if definition.MapName and not getMapLibrary():FindFirstChild(definition.MapName) then
		return false, `Map "{definition.MapName}" introuvable dans ServerStorage.MutationsMap.`
	end

	if definition.LightingName and not getLightingLibrary():FindFirstChild(definition.LightingName) then
		return false, `Lighting "{definition.LightingName}" introuvable dans ServerStorage.LightningFolder.`
	end

	return true
end

local function applyMode(modeName, definition)
	local mapApplied, mapError = true, nil
	if definition.MapName then
		mapApplied, mapError = applyMapTemplate(
			definition.MapName,
			nil,
			definition.TargetPosition,
			definition.SpawnLocationBehavior
		)
	end

	if not mapApplied then
		restoreEnvironment()
		ServerLuckManager:ClearMapMutationBoost()
		return false, mapError
	end

	local lightingApplied, lightingError = true, nil
	if definition.LightingName then
		lightingApplied, lightingError = applyLightingTemplate(definition.LightingName)
	end

	if not lightingApplied then
		restoreEnvironment()
		ServerLuckManager:ClearMapMutationBoost()
		return false, lightingError
	end

	local cleanup = nil
	if definition.OnEnter then
		local ok, cleanupOrNil, enterError = pcall(definition.OnEnter, definition)
		if not ok then
			restoreEnvironment()
			ServerLuckManager:ClearMapMutationBoost()
			return false, cleanupOrNil
		end

		if cleanupOrNil == nil and enterError then
			restoreEnvironment()
			ServerLuckManager:ClearMapMutationBoost()
			return false, enterError
		end

		if typeof(cleanupOrNil) == "function" then
			cleanup = cleanupOrNil
		end
	end

	activeModeCleanup = cleanup
	setActiveMutation(modeName)
	ServerLuckManager:SetMapMutationBoost(MAP_MUTATION_SERVER_LUCK_MULTIPLIER, MAP_MUTATION_SERVER_LUCK_DURATION)
	return true, `Mode actif: {modeName}.`
end

function MapMutationManager:ResetToNormal(clearAllLuckBoosts)
	self:Init()

	return runMapTransition(function()
		restoreEnvironment()
		clearLuckBoost(clearAllLuckBoosts)

		return true, "Map restoree en mode Normal."
	end)
end

function MapMutationManager:ExpireActiveMutation()
	self:Init()

	if activeMutation == "Normal" then
		return false, "Aucune mutation de map active a expirer."
	end

	return self:ResetToNormal(false)
end

function MapMutationManager:Init()
	if initialized then
		return
	end

	ServerLuckManager:Init()
	ServerLuckManager:SetMapMutationExpiredCallback(function()
		if activeMutation ~= "Normal" then
			self:ExpireActiveMutation()
		end
	end)
	backupOriginalMap()
	backupOriginalLighting()
	setActiveMutation("Normal")
	initialized = true
end

function MapMutationManager:GetActiveMutation()
	self:Init()
	return activeMutation
end

function MapMutationManager:GetSupportedMutations()
	local supported = {}

	for mutationName in pairs(MAP_DEFINITIONS) do
		table.insert(supported, mutationName)
	end

	table.sort(supported)
	return supported
end

function MapMutationManager:IsSupportedMutation(mutationName)
	local normalizedMutation = MutationModule:NormalizeName(mutationName or "Normal")
	return MAP_DEFINITIONS[normalizedMutation] ~= nil, normalizedMutation
end

function MapMutationManager:GetSupportedAdminAbuses()
	local supported = {}
	table.insert(supported, "Normal")

	for abuseName in pairs(ADMIN_ABUSE_DEFINITIONS) do
		table.insert(supported, abuseName)
	end

	table.sort(supported)
	return supported
end

function MapMutationManager:IsSupportedAdminAbuse(abuseName)
	local normalizedAbuse = tostring(abuseName or ""):match("^%s*(.-)%s*$") or ""
	if normalizedAbuse == "Normal" then
		return true, normalizedAbuse
	end

	return ADMIN_ABUSE_DEFINITIONS[normalizedAbuse] ~= nil, normalizedAbuse
end

function MapMutationManager:ApplyAdminMutation(mutationName)
	self:Init()

	local isSupported, normalizedMutation = self:IsSupportedMutation(mutationName)
	if not isSupported then
		return false, `Mutation "{tostring(mutationName)}" non supportee pour les maps.`
	end

	if normalizedMutation == "Normal" then
		return self:ResetToNormal(true)
	end

	return self:ApplyMutation(normalizedMutation)
end

function MapMutationManager:ApplyMutation(mutationName)
	self:Init()

	local isSupported, normalizedMutation = self:IsSupportedMutation(mutationName)
	if not isSupported then
		return false, `Mutation "{tostring(mutationName)}" non supportee pour les maps.`
	end

	if activeMutation == normalizedMutation then
		return true, `La map est deja en mode {normalizedMutation}.`
	end

	if normalizedMutation == "Normal" then
		return self:ResetToNormal(false)
	end

	local definition = MAP_DEFINITIONS[normalizedMutation]
	if not definition then
		return false, "Definition de map introuvable."
	end

	local definitionValid, definitionError = validateDefinition(definition, normalizedMutation)
	if not definitionValid then
		return false, definitionError
	end

	return runMapTransition(function()
		if activeMutation ~= "Normal" then
			restoreEnvironment()
		end

		return applyMode(normalizedMutation, definition)
	end)
end

function MapMutationManager:ApplyAdminAbuse(abuseName)
	self:Init()

	local isSupported, normalizedAbuse = self:IsSupportedAdminAbuse(abuseName)
	if not isSupported then
		return false, `Admin abuse "{tostring(abuseName)}" non supporte.`
	end

	if activeMutation == normalizedAbuse then
		return true, `Le mode {normalizedAbuse} est deja actif.`
	end

	if normalizedAbuse == "Normal" then
		return self:ResetToNormal(false)
	end

	local definition = ADMIN_ABUSE_DEFINITIONS[normalizedAbuse]
	if not definition then
		return false, `Definition d'admin abuse introuvable pour "{normalizedAbuse}".`
	end

	local definitionValid, definitionError = validateDefinition(definition, normalizedAbuse)
	if not definitionValid then
		return false, definitionError
	end

	return runMapTransition(function()
		if activeMutation ~= "Normal" then
			restoreEnvironment()
		end

		return applyMode(normalizedAbuse, definition)
	end)
end

return MapMutationManager
