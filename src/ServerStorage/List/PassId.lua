local RS = game:GetService("RunService")
local Players = game:GetService("Players")
local RP = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteEvent = require(RP:WaitForChild("MyService"):WaitForChild("Service"):WaitForChild("RemoteEvent"))
local DataManager = require(game.ServerStorage.Data.DataManager)
local ServerLuckManager = require(game.ServerStorage.Module.ServerLuckManager)

local _5Min = 300

return {
	FastRoll = {
		Id = 1692802337,
		DevProduct = false,
		apply = function(player : Player)
			--print("Ã  acheter la FastRoll")
		end,
	},
	VIP = {
		Id = 1693289944,
		DevProduct = false,
		apply = function(player : Player)
			local CashBuff = player:WaitForChild("Stats"):FindFirstChild("CashBuff")

			if CashBuff then
				local Buff = CashBuff:GetAttribute("Buff") or 0
				CashBuff:SetAttribute("Buff", Buff + 0.25)
			end
		end,
	},
	ServerLuck = {
		DevProduct = true,
		Id = 3543260926,
		apply = function(player : Player)
			local LuckServer = ServerScriptService:WaitForChild("Server"):WaitForChild("LuckServer")
			local default = LuckServer:GetAttribute("Time") or 0
			ServerLuckManager:Init()

			if LuckServer.Value == 1 then
				LuckServer.Value = 2
				LuckServer:SetAttribute("Time", default + _5Min * 3)
			elseif LuckServer.Value == 2 then
				LuckServer.Value = 4
				LuckServer:SetAttribute("Time", default + _5Min * 3)
			else
				warn("Max")
			end

			ServerLuckManager:RefreshClients()
		end,
	},
	X2Money = {
		Id = 1693008085,
		DevProduct = false,
		apply = function(player : Player)
			local CashBuff = player:WaitForChild("Stats"):FindFirstChild("CashBuff")
			
			if CashBuff then
				CashBuff.Value += 2
			end
			
		end,
	},
	["10KCash"] = {
		Id = 3543252673,
		DevProduct = false,
		apply = function(player : Player)
			local CashResult = 10000
			local Cash = player:WaitForChild("leaderstats"):WaitForChild("Cash")
			Cash.Value += CashResult
		end,
	},
	["100KCash"] = {
		Id = 3543253065,
		DevProduct = true,
		apply = function(player : Player)
			local CashResult = 100000
			local Cash = player:WaitForChild("leaderstats"):WaitForChild("Cash")
			Cash.Value += CashResult
		end,
	},
	["500KCash"] = {
		Id = 3543270323,
		DevProduct = true,
		apply = function(player : Player)
			local CashResult = 500000
			local Cash = player:WaitForChild("leaderstats"):WaitForChild("Cash")
			Cash.Value += CashResult
		end,
	},
	["1MCash"] = {
		Id = 3543256486,
		DevProduct = true,
		apply = function(player : Player)
			local CashResult = 1000000
			local Cash = player:WaitForChild("leaderstats"):WaitForChild("Cash")
			Cash.Value += CashResult
		end,
	},
	["10MCash"] = {
		Id = 3543256972,
		DevProduct = true,
		apply = function(player : Player)
			local CashResult = 10000000
			local Cash = player:WaitForChild("leaderstats"):WaitForChild("Cash")
			Cash.Value += CashResult
		end,
	},
	["Starter_Bundle"] = {
		Id = 3543270577,
		DevProduct = true,
		apply = function(player : Player)
			
		end,
	},
	["Big_Bundle"] = {
		Id = 3543270323,
		DevProduct = true,
		apply = function(player : Player)

		end,
	},
	["Founders_Edition_Bundle"] = {
		Id = 3543265507,
		DevProduct = true,
		apply = function(player : Player)

		end,
	},
}
