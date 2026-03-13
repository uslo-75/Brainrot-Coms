local Mutation = {}
local Workspace = game:GetService("Workspace")

local ACTIVE_MAP_MUTATION_SHARE = 25

Mutation.Mutation = {
	Normal = {Chance = 89, Multiplicateur = 1,},
	Gold = {Chance = 1, Multiplicateur = 2,},
	Diamond = {Chance = .1, Multiplicateur = 5,},
	Shiny = {Chance = .01, Multiplicateur = 20,},
	Spectral = {Chance = .07, Multiplicateur = 5,},
	Freeze = {Chance = .09, Multiplicateur = 3,},
	Solar = {Chance = .06, Multiplicateur = 6,},
	BubbleGum = {Chance = .045, Multiplicateur = 4,},
	Volcan = {Chance = 0.03, Multiplicateur = 8,},
	Electric = {Chance = 0.02, Multiplicateur = 10,},
}

Mutation.Aliases = {
	Volcano = "Volcan",
}

local function getMapMutationWeights(activeMutation)
	local normalizedMutation = Mutation:NormalizeName(activeMutation)
	if normalizedMutation == "Normal" or not Mutation.Mutation[normalizedMutation] then
		return nil
	end

	local adjustedWeights = {
		[normalizedMutation] = ACTIVE_MAP_MUTATION_SHARE,
	}

	local otherTotal = 0
	for name, mutation in pairs(Mutation.Mutation) do
		if name ~= normalizedMutation then
			otherTotal += mutation.Chance
		end
	end

	if otherTotal <= 0 then
		return adjustedWeights
	end

	local remainingShare = 100 - ACTIVE_MAP_MUTATION_SHARE
	for name, mutation in pairs(Mutation.Mutation) do
		if name ~= normalizedMutation then
			adjustedWeights[name] = (mutation.Chance / otherTotal) * remainingShare
		end
	end

	return adjustedWeights
end

function Mutation:GetNames()
	local names = {}

	for name in pairs(self.Mutation) do
		table.insert(names, name)
	end

	table.sort(names)
	return names
end

function Mutation:NormalizeName(name)
	if not name or name == "" then
		return "Normal"
	end

	return self.Aliases[name] or name
end

function Mutation:IsMutation(name)
	local normalized = self:NormalizeName(name)
	return self.Mutation[normalized] ~= nil, normalized
end

function Mutation:GetLookupNames(name)
	local normalized = self:NormalizeName(name)
	local names = { normalized }

	if normalized == "Volcan" then
		table.insert(names, "Volcano")
	end

	return names
end


function Mutation:RandomMutation(luckBuff)
	luckBuff = luckBuff or 1
	local total = 0
	local activeMapMutation = Workspace:GetAttribute("ActiveMapMutation")
	local activeWeights = getMapMutationWeights(activeMapMutation)

	for name, mutation in pairs(self.Mutation) do
		local weight = activeWeights and activeWeights[name] or mutation.Chance
		total = total + (weight * luckBuff)
	end

	local roll = math.random() * total
	local current = 0

	for name, mutation in pairs(self.Mutation) do
		local weight = activeWeights and activeWeights[name] or mutation.Chance
		current = current + (weight * luckBuff)
		if roll <= current then
			return name, mutation
		end
	end

	return next(self.Mutation)
end

function Mutation:GetMuta(name)
	return Mutation.Mutation[self:NormalizeName(name)] or Mutation.Mutation.Normal
end

function Mutation:SetBrainrotMutation(...)
	local Halls = {...}
	local Mutation_Name = Halls[1]
	local Muta = self:GetMuta(Mutation_Name or "Normal")
	local Add = {}
	
	table.insert(Add, Muta.Multiplicateur)
	return Add
end

function Mutation:Multiplicater(AllMutation)
	local Multiplicaters = 0
	if AllMutation and #AllMutation > 0 then
		for _, m in pairs(AllMutation) do
			Multiplicaters += m
		end
	else
		Multiplicaters = 1
	end
	return Multiplicaters
end

return Mutation
