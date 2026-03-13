local LuckBuff = {}

local ServerLuckManager = require(game.ServerStorage.Module.ServerLuckManager)


function LuckBuff:AllLuck(player)
	local finalLuck = 1

	if player then
		local stats = player:WaitForChild("Stats")
		local luckBuff = stats:WaitForChild("LuckBuff")
		
		finalLuck *= 1 + (luckBuff.Value / 100)
	end

	
	finalLuck *= ServerLuckManager:GetEffectiveMultiplier()

	return finalLuck
end

return LuckBuff
