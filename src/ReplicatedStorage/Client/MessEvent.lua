local RP = game:GetService("ReplicatedStorage")

local MessageModule = require(RP:WaitForChild("Module"):WaitForChild("MessageModule"))

local MessEvent = {}

function MessEvent:Init(player, ...)
	local Halls = { ... }
	local ClientType = Halls[1]

	if ClientType == "Send" then
		local Message = Halls[2]
		local LifeTime = Halls[3]
		local Color = Halls[4]

		MessageModule:SendMessage(player, Message, LifeTime, Color)
	end
end

return MessEvent
