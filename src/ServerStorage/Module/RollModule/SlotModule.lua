local SlotModule = {}

SlotModule.Slot = {
	["1"] = { Chance = 90 },
	["2"] = { Chance = 35 },
	["3"] = { Chance = 2 },
	["4"] = { Chance = 1 },
	["5"] = { Chance = 0.5 },
	["6"] = { Chance = 0.1 },
	["7"] = { Chance = 0.05 },
	["8"] = { Chance = 0.01 },
	["9"] = { Chance = 0.005 },
	["10"] = { Chance = 0.001 },
}

function SlotModule:RandomSlot(luckBuff)
	luckBuff = luckBuff or 1
	local total = 0

	for _, slot in pairs(self.Slot) do
		total = total + slot.Chance * luckBuff
	end

	local roll = math.random() * total
	local current = 0

	for name, slot in pairs(self.Slot) do
		current = current + slot.Chance * luckBuff
		if roll <= current then
			return name, slot
		end
	end

	return next(self.Slot)
end

return SlotModule
