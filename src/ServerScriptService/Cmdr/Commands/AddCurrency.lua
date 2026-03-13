return {
	Name = "AddCurrency",
	Aliases = {"ac"},
	Description = "Ajouter ou retirer une currency a un joueur",
	Group = "Admin",
	Args = {
		{
			Type = "currency",
			Name = "Currency",
			Description = "Nom de la currency a modifier",
		},
		{
			Type = "number",
			Name = "Amount",
			Description = "Montant a ajouter ou retirer",
		},
		{
			Type = "player",
			Name = "Player",
			Description = "Joueur cible",
			Optional = true,
		},
	},
}
