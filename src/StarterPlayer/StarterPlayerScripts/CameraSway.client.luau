local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local RP = game:GetService("ReplicatedStorage")

local ClientSettings = require(RP:WaitForChild("Module"):WaitForChild("ClientSettings"))
local Turn = 0
local cameraEffectsEnabled = true

local Lerp = function(a, b, t)
	return a + (b - a) * t
end;

ClientSettings:WaitUntilLoaded(10)
cameraEffectsEnabled = ClientSettings:GetToggle("CameraEffectsEnabled")

ClientSettings:ObserveToggle("CameraEffectsEnabled", function(value)
	cameraEffectsEnabled = value == true

	if not cameraEffectsEnabled then
		Turn = 0
	end
end, false)

RunService:BindToRenderStep("CameraSway", Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
	if not cameraEffectsEnabled then
		return
	end

	local Camera = workspace.CurrentCamera
	if not Camera then
		return
	end

	local MouseDelta = UserInputService:GetMouseDelta()

	Turn = Lerp(Turn, math.clamp(MouseDelta.X, -2, 2), (5 * deltaTime))

	Camera.CFrame = Camera.CFrame * CFrame.Angles(0, 0, math.rad(Turn))
end)
