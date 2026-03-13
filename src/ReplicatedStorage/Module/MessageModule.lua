local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local RP = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")

local MyService = require(RP:WaitForChild("MyService"):WaitForChild("MyService"))

local MessageModule = {}

function MessCreate(mess, lifeTime, textColor, name)
	
	if not mess then
		warn(tostring(mess), tostring(lifeTime), tostring(textColor))
		return
	end
	
	if RS:IsClient() and mess then
		local Gui = MyService:LoadService("Gui") or MyService:GetService("Gui")
		local MainGui = Gui:GetGuiByName("MainGui")
		
		local Template = MainGui.Message.Template:Clone()
		Template.Parent = MainGui.Message
		Template.Visible = true
		Template.Text = mess
		Template.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
		Template.TextTransparency = 1
		Template.Name = name or "Clone"
		
		TS:Create(Template, TweenInfo.new(.25), {TextTransparency = 0}):Play()
		
		if lifeTime then
			game.Debris:AddItem(Template, lifeTime)
		end
		
	end
end

function MessageModule:Remove(player, name)
	if RS:IsClient() then
		local Gui = MyService:LoadService("Gui") or MyService:GetService("Gui")
		local MainGui = Gui:GetGuiByName("MainGui")
		
		local Template = MainGui.Message:FindFirstChild(name)
		if Template then
			TS:Create(Template, TweenInfo.new(.25), {TextTransparency = 1}):Play()
			game.Debris:AddItem(Template, .25)
		end
	end
end

function MessageModule:SendMessage(player, ...)
	local halls = {...}
	if RS:IsServer() then
		local RemoteEvent = MyService:LoadService("RemoteEvent") or MyService:GetService("RemoteEvent")
		
		RemoteEvent:FireClient("MessEvent", player, "Send", table.unpack(halls))
		
	else
		local mess = halls[1]
		local lifetTime = halls[2]
		local TextColor = halls[3]
		MessCreate(mess, lifetTime, TextColor)
	end
end

return MessageModule
