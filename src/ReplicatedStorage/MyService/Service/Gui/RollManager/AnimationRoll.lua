local RunService = game:GetService("RunService")

local AnimRoll = {}

local SPEED = 2.5
local connection = nil
local timeAcc = 0

function AnimRoll:Start(frame)
	if connection then
		connection:Disconnect()
		connection = nil
	end
	
	local Base = frame.Asset.Base
	
	local stroke = Base:WaitForChild("UIStroke")
	local V1gradient = stroke:WaitForChild("UIGradient")
	
	
	V1gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 255, 255)),   
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 255, 255)),   

		ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 0, 0)),        

		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 255, 255)),  
		ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 255, 255))   
	})
	stroke.Color = Color3.new(1, 1, 1)

	if frame:FindFirstChild("ContentContainer") == nil then
		local container = Instance.new("Frame")
		container.Name = "ContentContainer"
		container.Size = UDim2.fromScale(1, 1)
		container.BackgroundTransparency = 1
		container.BorderSizePixel = 0
		container.ZIndex = 2
		container.Parent = frame

		
	end

	if frame:FindFirstChild("ShineEffect") then
		frame.ShineEffect:Destroy()
	end

	frame.ClipsDescendants = true

	local shine = Instance.new("Frame")
	shine.Name = "ShineEffect"
	shine.Size = UDim2.fromScale(1, 1)
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0
	shine.BorderSizePixel = 0
	shine.ZIndex = 1
	shine.Parent = frame

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 45
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4, 1),
		NumberSequenceKeypoint.new(0.5, 0.7),
		NumberSequenceKeypoint.new(0.6, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = shine

	timeAcc = 0
	connection = RunService.RenderStepped:Connect(function(dt)
		if not frame.Parent then
			connection:Disconnect()
			connection = nil
			return
		end
		timeAcc += dt
		gradient.Offset = Vector2.new((timeAcc * SPEED) % 3 - 1.5, 0)
		
		local currentRotation = (os.clock() * 60 * SPEED) % 360
		V1gradient.Rotation = currentRotation
	end)
end

function AnimRoll:Stop(frame)
	if connection then
		connection:Disconnect()
		connection = nil
	end

	if frame:FindFirstChild("ShineEffect") then
		frame.ShineEffect:Destroy()
	end
end

return AnimRoll

