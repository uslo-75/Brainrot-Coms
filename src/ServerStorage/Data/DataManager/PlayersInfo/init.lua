local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Template = require(script.Template)

local PlayersInfo = {}

PlayersInfo["Players"] = {}

PlayersInfo._index = PlayersInfo

function PlayersInfo.new(player)
	local self = setmetatable({}, {__index = PlayersInfo})
	
	self.Player = player
	self.Info = Template
	self.Char = player.Character or player.CharacterAdded:Wait() or Workspace:WaitForChild("Lives"):FindFirstChild(player.Name)
	
	PlayersInfo["Players"][self.Player.UserId] = self
	
	return self
end

function PlayersInfo:Apply(player)
	
end

function PlayersInfo:GetInfoFromUserId(_userId)
	for index, player in PlayersInfo["Players"] do
		if player.Player.UserId == _userId then
			return player
		end
	end
end

function PlayersInfo:Init()
	
	Players.PlayerAdded:Connect(function(player)
		local plr = PlayersInfo.new(player)
		print(plr)
		PlayersInfo:Apply(player)
	end)
	
	return true
end

return PlayersInfo
