local Players = game:GetService("Players")
local Air = Enum.Material.Air

local Effects = workspace:FindFirstChild("Effects")::Folder
if not Effects then
	Effects = Instance.new("Folder")
	Effects.Name = "Effects"
	Effects.Parent = workspace
end

local StateBlacklist = {Enum.HumanoidStateType.Jumping,Enum.HumanoidStateType.Freefall,Enum.HumanoidStateType.Landed}
local TWInfo = TweenInfo.new(1, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
local tspawn = task.spawn
local find = table.find
local V3New = Vector3.new
local CFNew = CFrame.new
local Angles = CFrame.Angles
local pi = math.pi
local random = math.random
local rad = math.rad

local SmokeTemplate = Instance.new("Part")  -- Customise your particle here -- ??
SmokeTemplate.Anchored = true
SmokeTemplate.CanCollide = false
SmokeTemplate.Size = V3New(1.6,1.6,1.6)
SmokeTemplate.TopSurface = Enum.SurfaceType.Smooth
SmokeTemplate.BottomSurface = Enum.SurfaceType.Smooth
SmokeTemplate.Color = Color3.new(1,1,1)
SmokeTemplate.Transparency = 0.65

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local MAX_EFFECT_DISTANCE = 120

local function CreateTween(instance:Instance, tweenInfo:TweenInfo, propertyTable:{[string]:any})
	local Tween = TweenService:Create(instance, tweenInfo, propertyTable)
	Tween:Play()
	Tween.Completed:Wait()
	Tween:Destroy()
end

local function CreateSmoke(Position:Vector3, MoveDirection:Vector3)
	local Smoke = SmokeTemplate:Clone()
	Smoke.CFrame = CFNew(Position-V3New(0,3,0)+Vector3.new(random()*2-1,0,random()*2-1)) * Angles(rad(random(0, 359)),rad(random(0, 359)),rad(random(0, 359)))
	Smoke.Parent = Effects
	local Spread = Angles(0,(random()-0.5)/2*pi,0):VectorToWorldSpace(MoveDirection)

	CreateTween(Smoke, TWInfo, {
		Position = Smoke.Position - Spread*3;
		Orientation = Smoke.Orientation + V3New(random(-45,45),random(-45,45),random(-45,45));
		Transparency = 1;
		Size = V3New(0.5,0.5,0.5)  -- Customise what the particle becomes after appearing
	})
	Smoke:Destroy()
end

local cooldown = 0
game:GetService("RunService").Heartbeat:Connect(function(delta:number)
	cooldown += delta
	if cooldown >= 0.1 then -- Customise the cooldown here
		cooldown %= 0.1 -- And here
		local PlayerList = Players:GetPlayers()
		local currentCamera = Workspace.CurrentCamera
		local cameraPosition = currentCamera and currentCamera.CFrame.Position
		for i,Player:Player in PlayerList do
			local Character = Player.Character
			if not Character or not Character:FindFirstChild("HumanoidRootPart") or not Character:FindFirstChildOfClass("Humanoid") then
				continue
			end

			local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")::BasePart
			local Humanoid = Character:FindFirstChildOfClass("Humanoid")
			if cameraPosition and (HumanoidRootPart.Position - cameraPosition).Magnitude > MAX_EFFECT_DISTANCE then
				continue
			end
			if Humanoid.FloorMaterial ~= Air and not find(StateBlacklist, Humanoid:GetState()) and HumanoidRootPart.AssemblyLinearVelocity.Magnitude >= 18 then -- Customise the required speed for the particles here
				tspawn(CreateSmoke, HumanoidRootPart.Position, Humanoid.MoveDirection)
			end
		end
	end
end)
