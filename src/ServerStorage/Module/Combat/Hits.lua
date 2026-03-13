local Hits = {}
local ServerStorage = game:GetService("ServerStorage")

-- Ragdoll + knockback

local function Ragdoll(char, lifeTime)
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then return end

	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	humanoid.AutoRotate = false
	humanoid.PlatformStand = true
	
	char:SetAttribute("Ragdoll", true)

	for _, motor in ipairs(char:GetDescendants()) do
		if motor:IsA("Motor6D") then
			local p0, p1 = motor.Part0, motor.Part1
			if not p0 or not p1 then continue end

			local a0 = Instance.new("Attachment")
			local a1 = Instance.new("Attachment")
			a0.CFrame = motor.C0
			a1.CFrame = motor.C1
			a0.Parent = p0
			a1.Parent = p1

			local socket = Instance.new("BallSocketConstraint")
			socket.Attachment0 = a0
			socket.Attachment1 = a1
			socket.Parent = p0

			motor.Enabled = false
		end
	end

	if lifeTime and lifeTime > 0 then
		task.delay(lifeTime, function()
			for _, obj in ipairs(char:GetDescendants()) do
				if obj:IsA("BallSocketConstraint") or obj:IsA("Attachment") then
					obj:Destroy()
				end
				if obj:IsA("Motor6D") then
					obj.Enabled = true
				end
			end
			humanoid.PlatformStand = false
			humanoid.AutoRotate = true
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			char:SetAttribute("Ragdoll", nil)
		end)
	end
end


local function Knockback(attackerChar, targetChar, Power)
	local attackerRoot = attackerChar:FindFirstChild("HumanoidRootPart")
	local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
	if not attackerRoot or not targetRoot then return end

	local direction = attackerRoot.CFrame.LookVector
	local force = direction * Power + Vector3.new(0, Power * 0.6, 0)

	local bv = Instance.new("BodyVelocity")
	bv.Velocity = force
	bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	bv.Parent = targetRoot

	game:GetService("Debris"):AddItem(bv, 0.25)
end

function Hits:Hit(char, EnemyChar, Info)
	if Info then
		if Info.Damage then
			EnemyChar.Humanoid:TakeDamage(Info.Damage)
		end
		if Info.Power and Info.Ragdoll then
			Ragdoll(EnemyChar, Info.Ragdoll)
			Knockback(char, EnemyChar, Info.Power)
		end
	end
end

return Hits
