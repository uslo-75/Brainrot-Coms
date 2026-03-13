local Local = {}
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RP = game:GetService("ReplicatedStorage")

local GamePasses = require(game.ServerStorage.List.PassId)

local function ApplyAllGamePasses(player)
	for _, data in pairs(GamePasses) do
		if not data.DevProduct then
			local success, hasPass = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, data.Id)
			end)

			if success and hasPass then
				data.apply(player)
			end
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	ApplyAllGamePasses(player)
end)

MarketplaceService.PromptProductPurchaseFinished:Connect(function(player, productId, purchased)
	if not purchased then return end

	for _, data in pairs(GamePasses) do
		if data.Id == productId then
			print("Le joueur "..player.Name.." a achetÃ© le produit : "..data.Name)
			data.apply(player)
			break
		end
	end
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then return end

	for _, data in pairs(GamePasses) do
		if data.Id == passId then
			data.apply(player)
			break
		end
	end
end)

return Local