local Club = {}
local TomatoHitbox = require(game.ServerStorage.Module.Combat.TomatoHitbox)
local Cooldown = require(game.ServerStorage.Module.Combat.Cooldown)
local HitsModule = require(game.ServerStorage.Module.Combat.Hits)

function Club:Init(player, tool, Info)
	local char = player.Character or player.CharacterAdded:Wait()
	if Cooldown:Check(char, "BatHit") then return end
	
	Cooldown:Start(char, "BatHit", Info.Info.Cooldown)
	
	local newHitbow = TomatoHitbox.new()
	local AnimTrack = char.Humanoid:LoadAnimation(script.Hit)
	local isTouch = false
	newHitbow.Size = Info.Info.HitboxSize or Vector3.new(4,4,4)
	newHitbow.Offset = Info.Info.HitboxOffset or CFrame.new(0,0,-2)
	newHitbow.CFrame = char:WaitForChild("HumanoidRootPart")
	newHitbow.Visualizer = false
	
	tool.Handle.Swing:Play()
	
	newHitbow:Start()
	AnimTrack:Play()
	
	
	newHitbow.onTouch = function(humanoid)
		if humanoid ~= char:WaitForChild("Humanoid") then
			HitsModule:Hit(char, humanoid.Parent, Info.Info)
			tool.Handle.Hit:Play()
		end
	end
	
	task.delay(Info.Info.HitboxDuration or .25, function()
		newHitbow:Stop()
		newHitbow:Destroy()
	end)
end

return Club
