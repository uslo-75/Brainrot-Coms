local ViewPortModule = {}
ViewPortModule.__index = ViewPortModule

local RS = game:GetService("RunService")

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

local function IsAlive(instance)
	return instance ~= nil and instance.Parent ~= nil
end

function ViewPortModule:_DisconnectRotation()
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end
end

function ViewPortModule:ClearAllChildren()
	self:_DisconnectRotation()
	self:StopAnimation()
	
	for _, v in pairs(self.ViewportFrame:GetChildren()) do
		if v:IsA("Camera") or v:IsA("WorldModel") or v:IsA("Model") then
			v:Destroy()
		end
	end
end

function ViewPortModule.new(model, viewportFrame, value)
	local self = setmetatable({}, ViewPortModule)

	self.ViewportFrame = viewportFrame
	self.Model = model
	self.Connection = nil
	self.Speed = 10
	self.Active = value or false

	self:ClearAllChildren()

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = self.ViewportFrame

	self.Model.Parent = worldModel

	local camera = Instance.new("Camera")
	camera.Parent = self.ViewportFrame
	self.ViewportFrame.CurrentCamera = camera
	self.Camera = camera
	

	return self
end

function ViewPortModule:Start(offset, Value, anim)
	offset = offset or Vector3.new(0, .5, 6.5)

	if not EnsurePrimaryPart(self.Model) then
		return
	end
	
	if Value and anim then
		self:LoadAnimation(anim)
	end
	
	if self.Model:FindFirstChild("VfxInstance") then
		local Z = self.Model.VfxInstance.Size.Z
		local Y = self.Model.VfxInstance.Size.Y
		
		if Z > 3 then
			offset = Vector3.new(offset.X,offset.Y,offset.Z + (math.floor(Z)-1))
		end
		
		if Y > 5 then
			offset = Vector3.new(offset.X,offset.Y - math.floor(Y/4) ,offset.Z + math.floor(Y/2))
		end
	end
	
	self.Model:PivotTo(CFrame.new(0,0,0))

	self.Model:PivotTo(CFrame.new() * CFrame.Angles(0, math.pi, 0))

	self.Camera.CFrame = CFrame.lookAt(
		offset,
		Vector3.new(0, 2.5, 0)
	)
	
	if not self.Active then
		local stepEvent = RS:IsServer() and RS.Heartbeat or RS.RenderStepped

		self.Connection = stepEvent:Connect(function(dt)
			if not IsAlive(self.ViewportFrame) or not IsAlive(self.Model) or not IsAlive(self.Camera) then
				self:_DisconnectRotation()
				return
			end

			if not EnsurePrimaryPart(self.Model) then
				self:_DisconnectRotation()
				return
			end

			local currentPivot = self.Model:GetPivot()
			local rotation = CFrame.Angles(0, math.rad(self.Speed) * dt, 0)
			self.Model:PivotTo(currentPivot * rotation)
		end)

	end
	
	
end


function ViewPortModule:LoadAnimation(animationId)
	local humanoid = self.Model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end


	local animation = Instance.new("Animation")
	animation.AnimationId = animationId

	self.CurrentTrack = humanoid:LoadAnimation(animation)
	self.CurrentTrack:Play()
	self.CurrentTrack.Looped = true

	task.wait(0.1)

	if self.CurrentTrack.IsPlaying then
		--print("Animation en cours")
	else
		print("Animation non jouÃƒÆ’Ã‚Â©e")
	end
end


function ViewPortModule:StopAnimation()
	if self.CurrentTrack then
		self.CurrentTrack:Stop()
		self.CurrentTrack:Destroy()
		self.CurrentTrack = nil
	end
end

function ViewPortModule:StopAllAnimations()
	local humanoid = self.Model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		track:Stop()
	end
end


function ViewPortModule:Destroy()
	if self.ViewportFrame then
		self:ClearAllChildren()
	end

	self.Model = nil
	self.Camera = nil
	self.ViewportFrame = nil
end

return ViewPortModule
