local MessageModule = require(game.ReplicatedStorage.Module.MessageModule)
local ServerScriptService = game:GetService("ServerScriptService")
local MessagingService = game:GetService("MessagingService")
local ServerLuckManager = require(game.ServerStorage.Module.ServerLuckManager)

local EventsModule = {}

function EventsModule:LuckServer(player, amout, Time)
	if amout and typeof(amout) == "number" and amout > 0 then
		local luckServer = ServerScriptService.Server:WaitForChild("LuckServer")
		ServerLuckManager:Init()
		luckServer.Value = amout
		local currentTime = luckServer:GetAttribute("Time") or 0
		luckServer:SetAttribute("Time", currentTime + (Time or 900))

		local messageString = string.format("%s a ajoutÃ© la Luck X%s.", player.Name, tostring(amout))
		--MessagingService:PublishAsync("GlobaleMessage", {text = messageString, LifeTime = 1.5, ColorName = "White"})

		ServerLuckManager:RefreshClients()

		return messageString
	else
		return "Erreur : veuillez entrer un nombre valide !"
	end
end

return EventsModule
