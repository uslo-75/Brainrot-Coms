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
	if amount == 0 then
		return "Le montant doit etre different de 0."
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local currencyValue = leaderstats and leaderstats:FindFirstChild(currency)
	if not currencyValue then
		return `{currency} n'existe pas pour {player.Name}.`
	end

	if DataManager.AddCurrency(currency, amount, player) then
		local action = amount > 0 and "recu" or "perdu"
		return `{player.Name} a {action} {math.abs(amount)} {currency}.`
	end

	return "Une erreur est survenue."
end
