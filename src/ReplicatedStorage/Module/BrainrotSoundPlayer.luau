local Debris = game:GetService("Debris")
local RP = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local BrainrotSoundResolver = require(RP:WaitForChild("Module"):WaitForChild("BrainrotSoundResolver"))
local ClientSettings = require(RP:WaitForChild("Module"):WaitForChild("ClientSettings"))

local BrainrotSoundPlayer = {}

local brainrotSoundsEnabled = ClientSettings:GetToggle("BrainrotSoundsEnabled")
local activeSounds = {}

local function stopTrackedSound(sound)
	activeSounds[sound] = nil

	if sound and sound.Parent then
		sound:Stop()
		sound:Destroy()
	end
end

function BrainrotSoundPlayer:StopAll()
	for sound in pairs(activeSounds) do
		stopTrackedSound(sound)
	end
end

function BrainrotSoundPlayer:Play(result)
	if not brainrotSoundsEnabled then
		return nil
	end

	local sound = BrainrotSoundResolver.Resolve(result)
	if not sound then
		return nil
	end

	self:StopAll()

	local soundClone = sound:Clone()
	soundClone.Looped = false
	soundClone.Playing = false
	soundClone.TimePosition = 0
	soundClone.Parent = SoundService

	activeSounds[soundClone] = true

	soundClone.Ended:Connect(function()
		stopTrackedSound(soundClone)
	end)

	local cleanupTime = soundClone.TimeLength > 0 and (soundClone.TimeLength + 2) or 10
	Debris:AddItem(soundClone, cleanupTime)
	soundClone:Play()

	return soundClone
end

ClientSettings:ObserveToggle("BrainrotSoundsEnabled", function(value)
	brainrotSoundsEnabled = value == true

	if not brainrotSoundsEnabled then
		BrainrotSoundPlayer:StopAll()
	end
end)

return BrainrotSoundPlayer
