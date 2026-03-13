local RebirthFonction = {}

local RP = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Map = game.Workspace.Map

local BaseModule = require(ServerStorage.Module.GameHandler.Base)
local DataManager = require(ServerStorage.Data.DataManager)
local UpgradeList = require(game.ServerStorage.List.UpgradeList)
local GameConfig = require(RP:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local RemoteEvent = require(RP:WaitForChild("MyService"):WaitForChild("Service"):WaitForChild("RemoteEvent"))
local DEFAULT_WAIT_TIMEOUT = GameConfig.Shared.DefaultWaitTimeout

local function waitForChildQuiet(parent, childName, timeout)
	local deadline = os.clock() + (timeout or DEFAULT_WAIT_TIMEOUT)
	local child = parent and parent:FindFirstChild(childName)

	while parent and not child and os.clock() < deadline do
		task.wait(0.1)
		child = parent:FindFirstChild(childName)
	end

	return child
end

local function getLeaderstat(player, statName, timeout)
	local leaderstats = player:FindFirstChild("leaderstats") or waitForChildQuiet(player, "leaderstats", timeout)
	if not leaderstats then
		return nil
	end

	return leaderstats:FindFirstChild(statName) or waitForChildQuiet(leaderstats, statName, timeout)
end


function RebirthFonction:Init(player, ...)
	local Halls = {...}
	local EventType = Halls[1]
	
	if EventType == "Rebirth" then
		local Rebirth = getLeaderstat(player, "Rebirth")
		local Cash = getLeaderstat(player, "Cash")
		if not Rebirth or not Cash then
			return false, "Data is still loading"
		end
		
		local List = UpgradeList[tostring(Rebirth.Value + 1)]
		local BaseSelect = ServerStorage.Base:FindFirstChild(tostring(Rebirth.Value+1))
		local MyBase = BaseModule.GetBase(player)
		
		if not MyBase then
			return nil, "Error to the server sorry !"
		end
		
		if not List or not BaseSelect then
			return nil, "Error to the server sorry !"
		end
		
		if Cash.Value < List.Required.Cash then
			return false, "Need more Cash !"
		end
		
		if not DataManager:HassBrairot(player, List.Required.Brainrot) then
			return false, "You can't rebirth right now !"
		end
		
		local profile = DataManager:GetProfile(player)
		local Data = profile and profile.Data
		
		if not Data then
			return nil, "Error to the server sorry !"
		end
		
		local Folder = MyBase:Rebrith()

		if not Folder then
			warn(`Pas de folder trouvÃ© pour le joueur {player.Name}`)
			return nil, "Error to the server sorry !"
		end
		
		if DataManager then
			Data.Base.Brainrot = {}
			Data.AuraSpin = {
				Name = "",
				Position = "",
			}
			Data.Fuse = {
				Fusing = {},
				FuseEndTime = 0,
				FuseMode = "None",
			}
		end
		
		Rebirth.Value +=1
		Cash.Value = List.Reward.Cash
		RemoteEvent:InvokeClient("AuraSpin", player, "Empty")
		RemoteEvent:InvokeClient("AuraSpin", player, "BrairotPreview", false)
		RemoteEvent:InvokeClient("FuseEvent", player, "Clear")
		
		BaseModule.new(player, Data, DataManager)
		
		return true
	elseif EventType == "Update" then
		local Rebirth = getLeaderstat(player, "Rebirth")
		if not Rebirth then
			return false, {}
		end

		local List = UpgradeList[tostring(Rebirth.Value + 1)]
		
		if List then
			local value, result = DataManager:HassBrairot(player, List.Required.Brainrot)
			return value, result or {}
		end
		return nil, {}
	end

end

return RebirthFonction
