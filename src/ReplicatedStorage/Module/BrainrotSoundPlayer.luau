local Debris = game:GetService("Debris")
local RP = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local ClientSettings = require(RP:WaitForChild("Module"):WaitForChild("ClientSettings"))

local BrainrotSoundPlayer = {}

local brainrotSoundsEnabled = ClientSettings:GetToggle("BrainrotSoundsEnabled")
local brainrotSoundFolder = nil
local soundEntries = nil
local activeSounds = {}

local SOUND_NAME_ALIASES = {
	adminluckyblock = "Admin Llucky Block",
	banditobobritto = "BonditoBorbrito",
	blueberrinnioctopusini = "BluerberniOctosini",
	brribrribicusdicusbombicus = "BrrBrrDicosDicos",
	talpadifero = "Talpa Di Ferro",
}

local function stopTrackedSound(sound)
	activeSounds[sound] = nil

	if sound and sound.Parent then
		sound:Stop()
		sound:Destroy()
	end
end

local function normalizeName(value)
	if typeof(value) ~= "string" then
		return ""
	end

	local normalized = string.lower(value)
	normalized = normalized:gsub("^brainrotsound_", "")
	normalized = normalized:gsub("%s*%-%s*sound effect$", "")
	normalized = normalized:gsub("%s+sound$", "")
	normalized = normalized:gsub("[^%w]+", "")

	return normalized
end

local function getBrainrotSoundFolder()
	if brainrotSoundFolder and brainrotSoundFolder.Parent then
		return brainrotSoundFolder
	end

	brainrotSoundFolder = SoundService:FindFirstChild("BrainrotSound") or SoundService:WaitForChild("BrainrotSound", 5)
	return brainrotSoundFolder
end

local function rebuildSoundEntries()
	soundEntries = {}

	local folder = getBrainrotSoundFolder()
	if not folder then
		return soundEntries
	end

	for _, descendant in ipairs(folder:GetDescendants()) do
		if descendant:IsA("Sound") then
			table.insert(soundEntries, {
				Sound = descendant,
				NormalizedName = normalizeName(descendant.Name),
			})
		end
	end

	return soundEntries
end

local function getSoundEntries()
	return soundEntries or rebuildSoundEntries()
end

local function levenshteinDistance(left, right)
	local leftLength = #left
	local rightLength = #right

	if leftLength == 0 then
		return rightLength
	end

	if rightLength == 0 then
		return leftLength
	end

	local previousRow = table.create(rightLength + 1)
	local currentRow = table.create(rightLength + 1)

	for rightIndex = 0, rightLength do
		previousRow[rightIndex] = rightIndex
	end

	for leftIndex = 1, leftLength do
		currentRow[0] = leftIndex
		local leftCharacter = string.sub(left, leftIndex, leftIndex)

		for rightIndex = 1, rightLength do
			local cost = leftCharacter == string.sub(right, rightIndex, rightIndex) and 0 or 1
			local deletion = previousRow[rightIndex] + 1
			local insertion = currentRow[rightIndex - 1] + 1
			local substitution = previousRow[rightIndex - 1] + cost

			local best = deletion
			if insertion < best then
				best = insertion
			end
			if substitution < best then
				best = substitution
			end

			currentRow[rightIndex] = best
		end

		previousRow, currentRow = currentRow, previousRow
	end

	return previousRow[rightLength]
end

local function collectCandidateNames(result)
	local candidates = {}
	local seen = {}

	local function addCandidate(value)
		local normalized = normalizeName(value)
		if normalized == "" or seen[normalized] then
			return
		end

		seen[normalized] = true
		table.insert(candidates, normalized)

		local alias = SOUND_NAME_ALIASES[normalized]
		local aliasNormalized = normalizeName(alias)
		if aliasNormalized ~= "" and not seen[aliasNormalized] then
			seen[aliasNormalized] = true
			table.insert(candidates, aliasNormalized)
		end
	end

	if result then
		addCandidate(result.Name)

		if result.Data then
			addCandidate(result.Data.DisplayName)
		end
	end

	return candidates
end

local function resolveSound(result)
	local folder = getBrainrotSoundFolder()
	if not folder then
		return nil
	end

	local directCandidates = {
		result and result.Name,
		result and result.Data and result.Data.DisplayName,
	}

	for _, candidateName in ipairs(directCandidates) do
		if typeof(candidateName) == "string" and candidateName ~= "" then
			local directMatch = folder:FindFirstChild(candidateName, true)
			if directMatch and directMatch:IsA("Sound") then
				return directMatch
			end
		end
	end

	local candidates = collectCandidateNames(result)
	if #candidates == 0 then
		return nil
	end

	local bestMatch = nil
	local bestScore = 0

	for _, entry in ipairs(getSoundEntries()) do
		local normalizedSoundName = entry.NormalizedName

		for _, candidate in ipairs(candidates) do
			if normalizedSoundName == candidate then
				return entry.Sound
			end

			local score = 0

			if normalizedSoundName:find(candidate, 1, true) or candidate:find(normalizedSoundName, 1, true) then
				score = 85 - math.abs(#normalizedSoundName - #candidate)
			else
				local maxLength = math.max(#normalizedSoundName, #candidate)
				if maxLength > 0 then
					local similarity = 1 - (levenshteinDistance(candidate, normalizedSoundName) / maxLength)
					if similarity >= 0.78 then
						score = math.floor(similarity * 100)
					end
				end
			end

			if score > bestScore then
				bestScore = score
				bestMatch = entry.Sound
			end
		end
	end

	if bestScore >= 78 then
		return bestMatch
	end

	return nil
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

	local sound = resolveSound(result)
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
