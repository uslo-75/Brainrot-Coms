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

local function isInZone(part, position)
	local partPos = part.Position
	local size = part.Size

	local horizontalDist = Vector3.new(position.X, 0, position.Z) - Vector3.new(partPos.X, 0, partPos.Z)
	local halfX = size.X / 2
	local halfZ = size.Z / 2

	local insideHorizontal = math.abs(horizontalDist.X) <= halfX and math.abs(horizontalDist.Z) <= halfZ
	local verticalDist = math.abs(position.Y - partPos.Y)
	local insideVertical = verticalDist <= verticalTolerance

	return insideHorizontal
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
