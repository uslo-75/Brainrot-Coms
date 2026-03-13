local ProximityPromptEvent = {}

function ProximityPromptEvent:Init(player, ...)
	local Halls = { ... }
	local ClientType = Halls[1]

	if ClientType == "Return" then
		local promp1, prompt2 = Halls[2], Halls[3]
		print(promp1)
		print(prompt2)
	end
end

return ProximityPromptEvent
