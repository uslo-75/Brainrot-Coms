local MarketPlaceService = {}

local MarketplaceService = game:GetService("MarketplaceService")
local RP = game:GetService("ReplicatedStorage")
local RemoteEvent = require(RP:WaitForChild("MyService"):WaitForChild("Service"):WaitForChild("RemoteEvent"))

function MarketPlaceService:HassPass(player, name)
	local Id = RemoteEvent:InvokeServer("GetInfo", "PassId", name)
	if not Id then warn(`Pas d'id trouver au {name} !`) return nil end
	local success, hasPass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(
			player.UserId,
			Id
		)
	end)
	
	
	return hasPass
end

function MarketPlaceService:Purchase(player, name)
	

	
	local Id = RemoteEvent:InvokeServer("GetInfo", "PassId", name)
	if not Id then warn(`Pas d'id trouver au {name} !`) return nil end
	local success, hasPass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(
			player.UserId,
			Id
		)
	end)

	if success and hasPass then
		return false, hasPass
	else
		MarketplaceService:PromptGamePassPurchase(
			player,
			Id
		)
		return true
	end
end

return MarketPlaceService
