local ShopFonction = {}
local RP = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ItemsList = require(game.ServerStorage.List.ItemsInfo)
local GameConfig = require(RP:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local DEFAULT_WAIT_TIMEOUT = GameConfig.Shared.DefaultWaitTimeout
local SessionOwnedItems = setmetatable({}, { __mode = "k" })

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

local function GetPlayerSessionItems(player)
	local sessionItems = SessionOwnedItems[player]
	if not sessionItems then
		sessionItems = {}
		SessionOwnedItems[player] = sessionItems
	end

	return sessionItems
end

local function MarkItemOwned(player, name)
	GetPlayerSessionItems(player)[name] = true
end

local function HasSessionOwnership(player, name)
	local sessionItems = SessionOwnedItems[player]
	return sessionItems and sessionItems[name] == true or false
end

local function GetToolTemplate(name)
	return ServerStorage.Items:FindFirstChild(name)
end

local function MaxItems(player : Player, name : string)
	local count = 0
	for _, tool in pairs(player.Backpack:GetChildren()) do
		if tool.Name == name then
			count +=1
		end
	end
	local character = player.Character
	if character then
		for _, tool in pairs(character:GetChildren()) do
			if tool:IsA("Tool") and tool.Name == name then
				count +=1
			end
		end
	end
	return count
end

local function CanEquipItem(player, itemInfo, name)
	if not itemInfo then
		return false
	end

	if MaxItems(player, name) > 0 then
		return true
	end

	if itemInfo.Purchasable then
		return HasSessionOwnership(player, name)
	end

	return false
end

function ShopFonction:Init(player, ...)
	local Halls = {...}
	local EventType = Halls[1]
	
	if EventType == "ShopList" then
		return ItemsList
	elseif EventType == "Buy" then
		local Cash = getLeaderstat(player, "Cash")
		local Rebirth = getLeaderstat(player, "Rebirth")
		if not Cash or not Rebirth then
			return false, "Data is still loading", Color3.fromRGB(255, 0, 0)
		end
		
		if not Halls[2] then
			return nil, "Error server", Color3.new(1,0,0)
		end
		
		local itemInfo = ItemsList[Halls[2]]
		
		if not itemInfo then return nil, "Error server items not Found sorry !", Color3.new(1,0,0) end
		
		if Rebirth.Value < itemInfo.RebrithRequire then return false, "You don't have enough rebirth", Color3.new(1,0,0) end
		
		if itemInfo.Purchasable then
			local itemName = Halls[2]
			local Tool = GetToolTemplate(itemName)
			
			if Tool then
				local currentCount = MaxItems(player, itemName)

				if itemInfo.MaxUse then
					if currentCount >= itemInfo.MaxUse then
						return false, "You already have this item", Color3.fromRGB(255, 0, 0), currentCount
					end
				end

				if itemInfo.EquipedOnce and currentCount >= 1 then
					return false, "You already have this item", Color3.fromRGB(255, 0, 0), currentCount
				end

				if Cash.Value < itemInfo.Price then return false, "You don't have enough money", Color3.fromRGB(255, 0, 0) end

				Cash.Value -= itemInfo.Price

				Tool = Tool:Clone()
				Tool.Parent = player.Backpack
				MarkItemOwned(player, itemName)
				return true, "Purchase successful", Color3.fromRGB(0, 255, 0), currentCount + 1
			end

			return false, "Tool not found", Color3.fromRGB(255, 0, 0)
			
		end
	elseif EventType == "EquipTool" or EventType == "ToolEquip" then
		local name = Halls[2]
		local value = Halls[3]
		
		if not name then return nil, "Not name error !" end

		local itemInfo = ItemsList[name]
		if not itemInfo then
			return false, "Item not found"
		end
		
		if value then
			if not CanEquipItem(player, itemInfo, name) then
				return false, "Item not owned"
			end

			if MaxItems(player, name) > 0 then
				return true
			end

			if itemInfo.MaxUse and MaxItems(player, name) >= itemInfo.MaxUse then
				return false, "You already have this item"
			end

			local Tool = GetToolTemplate(name)
			if Tool then
				local Tool = Tool:Clone()
				Tool.Parent = player.Backpack
				return true
			end
		else
			local character = player.Character
			local toolName = player.Backpack:FindFirstChild(name) or (character and character:FindFirstChild(name))
			if toolName then
				toolName:Destroy()
				return true
			end
		end
		
		return nil, "Error !"
	end	
end

return ShopFonction
