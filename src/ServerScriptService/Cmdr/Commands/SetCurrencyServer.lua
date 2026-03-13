local DataManager = require(game.ServerStorage.Data.DataManager)

return function(context, currency: string, amount: number, player: Player?)
	player = player or context.Executor

	if not player or player.Parent == nil then
		return "Joueur introuvable."
	end

	if typeof(amount) ~= "number" or amount ~= amount or math.abs(amount) == math.huge then
		return "Montant invalide."
	end

	amount = math.round(amount)

	local leaderstats = player:FindFirstChild("leaderstats")
	local currencyValue = leaderstats and leaderstats:FindFirstChild(currency)
	if not currencyValue then
		return `{currency} n'existe pas pour {player.Name}.`
	end

	local currentValue = currencyValue.Value
	local delta = amount - currentValue
	if delta == 0 then
		return `{player.Name} a deja {amount} {currency}.`
	end

	if DataManager.AddCurrency(currency, delta, player) then
		return `{player.Name} a maintenant {amount} {currency}.`
	end

	return "Une erreur est survenue."
end
