local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local resetBindable = Instance.new("BindableEvent")

local function setResetCallback()
	for _ = 1, 20 do
		local success = pcall(function()
			StarterGui:SetCore("ResetButtonCallback", resetBindable)
		end)

		if success then
			return true
		end

		task.wait(0.25)
	end

	return false
end

resetBindable.Event:Connect(function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = 0
	end
end)

task.spawn(setResetCallback)
