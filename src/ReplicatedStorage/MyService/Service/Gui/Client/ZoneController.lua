local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local ZoneFolder = Workspace:WaitForChild("Zone")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")

local ZoneController = {}

-- Events
ZoneController.EnterZone = Instance.new("BindableEvent")
ZoneController.LeaveZone = Instance.new("BindableEvent")

-- Settings
local verticalTolerance = 5
local currentZone = nil
local zones = {}
local zoneCheckAccumulator = 0
local ZONE_CHECK_INTERVAL = 0.1

local function refreshZones()
	table.clear(zones)
	for _, zone in ipairs(ZoneFolder:GetChildren()) do
		if zone:IsA("BasePart") then
			table.insert(zones, zone)
		end
	end
end

local function bindCharacter(newChar)
	char = newChar
	root = newChar:WaitForChild("HumanoidRootPart")
	currentZone = nil
end

-- Utils

local function getZoneShape(part)
	local attributeShape = string.lower(tostring(part:GetAttribute("ZoneShape") or ""))
	if attributeShape == "circle" or attributeShape == "cylinder" then
		return "circle"
	end

	if attributeShape == "sphere" or attributeShape == "ball" then
		return "sphere"
	end

	if part:IsA("Part") then
		if part.Shape == Enum.PartType.Cylinder then
			return "cylinder"
		end

		if part.Shape == Enum.PartType.Ball then
			return "sphere"
		end
	end

	return "block"
end

local function isInZone(part, position)
	local localPosition = part.CFrame:PointToObjectSpace(position)
	local size = part.Size
	local zoneShape = getZoneShape(part)

	if zoneShape == "cylinder" then
		local radius = math.min(size.Y, size.Z) / 2
		local radialDistance = Vector2.new(localPosition.Y, localPosition.Z).Magnitude
		local insideRadius = radialDistance <= radius
		local insideHeight = math.abs(localPosition.X) <= (size.X / 2) + verticalTolerance
		return insideRadius and insideHeight
	end

	if zoneShape == "circle" then
		local radius = math.min(size.X, size.Z) / 2
		local radialDistance = Vector2.new(localPosition.X, localPosition.Z).Magnitude
		local insideRadius = radialDistance <= radius
		local insideHeight = math.abs(localPosition.Y) <= (size.Y / 2) + verticalTolerance
		return insideRadius and insideHeight
	end

	if zoneShape == "sphere" then
		local radius = math.min(size.X, size.Y, size.Z) / 2
		return localPosition.Magnitude <= radius + verticalTolerance
	end

	local insideHorizontal = math.abs(localPosition.X) <= (size.X / 2) and math.abs(localPosition.Z) <= (size.Z / 2)
	local insideVertical = math.abs(localPosition.Y) <= (size.Y / 2) + verticalTolerance

	return insideHorizontal and insideVertical
end

-- Init

function ZoneController:Init()
	player.CharacterAdded:Connect(bindCharacter)
	ZoneFolder.ChildAdded:Connect(refreshZones)
	ZoneFolder.ChildRemoved:Connect(refreshZones)
	refreshZones()

	RunService.Heartbeat:Connect(function(dt)
		zoneCheckAccumulator += dt
		if zoneCheckAccumulator < ZONE_CHECK_INTERVAL then
			return
		end

		zoneCheckAccumulator = 0

		if not root or not root.Parent then
			return
		end

		local newZone = nil
		for _, zone in ipairs(zones) do
			if isInZone(zone, root.Position) then
				newZone = zone.Name
				break
			end
		end

		-- Enter
		if newZone and newZone ~= currentZone then
			if currentZone then
				self.LeaveZone:Fire(currentZone)
			end

			currentZone = newZone
			self.EnterZone:Fire(currentZone)
		end

		-- Leave
		if not newZone and currentZone then
			self.LeaveZone:Fire(currentZone)
			currentZone = nil
		end
	end)
end

return ZoneController
