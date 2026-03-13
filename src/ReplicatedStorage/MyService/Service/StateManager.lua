local Players = game:GetService("Players")

local StateManager = {}

local states = {}
local stunTimers = {}

function StateManager.ReturnStates(plater)
	return states[plater]
end

function StateManager.GetState(player, statekey)
	if states[player] then
		return states[player][statekey]
	end
	return nil
end

function StateManager.SetState(player, statekey, value, duration)
	if not states[player] then
		states[player] = {}
	end
	
	states[player][statekey] = value
	
	if duration and type(duration) == "number" then
		task.delay(duration, function()
			if states[player] then
				states[player][statekey] = nil
				
				if next(states[player]) == nil then
					states[player] = nil
				end
			end
		end)
	end
end

function StateManager.RemoveStates(player, stateKey)
	if not states[player] then return end
	
	if stateKey then
		states[player][stateKey] = nil
		if next(states[player]) == nil then
			states[player] = nil
		end
	else
		states[player] = nil
	end
end

function StateManager.ClearAllStates()
	for plr in pairs(states) do
		states[plr] = nil
	end
	for plr in pairs(stunTimers) do
		stunTimers[plr] = nil
	end
end

function StateManager.SetStun(plr, value, duration, stunSpeed)
	if not plr or not plr.Character or not plr.Character:FindFirstChild("Humanoid") then return end

	local humanoid = plr.Character:FindFirstChild("Humanoid")

	if not states[plr] then
		states[plr] = {}
	end

	if value then
		states[plr]["Stunned"] = true

		if not states[plr].OriginalWalkSpeed then
			states[plr].OriginalWalkSpeed = humanoid.WalkSpeed
		end

		humanoid.WalkSpeed = stunSpeed or 0

		local endTime = time() + duration

		if stunTimers[plr] then
			stunTimers[plr].EndTime = math.max(stunTimers[plr].EndTime, endTime)
		else
			stunTimers[plr] = { EndTime = endTime }

			coroutine.wrap(function()
				while stunTimers[plr] and time() < stunTimers[plr].EndTime do
					task.wait(0.1)
				end

				if states[plr] then
					states[plr]["Stunned"] = nil

					if plr.Character and plr.Character:FindFirstChild("Humanoid") then
						local currentHumanoid = plr.Character:FindFirstChild("Humanoid")
						currentHumanoid.WalkSpeed = states[plr].OriginalWalkSpeed or 16
					end

					states[plr].OriginalWalkSpeed = nil

					if next(states[plr]) == nil then
						states[plr] = nil
					end
				end

				stunTimers[plr] = nil
			end)()
		end
	else
		states[plr]["Stunned"] = nil

		if plr.Character and plr.Character:FindFirstChild("Humanoid") then
			local currentHumanoid = plr.Character:FindFirstChild("Humanoid")
			currentHumanoid.WalkSpeed = states[plr].OriginalWalkSpeed or 16
		end

		states[plr].OriginalWalkSpeed = nil
		stunTimers[plr] = nil

		if next(states[plr]) == nil then
			states[plr] = nil
		end
	end
end


Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
	stunTimers[player] = nil
end)

return StateManager
