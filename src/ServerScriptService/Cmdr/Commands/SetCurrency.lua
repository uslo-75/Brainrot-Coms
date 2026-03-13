return {
	Name = "SetCurrency",
	Aliases = {"sc", "setcash"},
	Description = "Definir une currency a une valeur exacte",
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
			Description = "Valeur finale a appliquer",
		},
		{
			Type = "player",
			Name = "Player",
			Description = "Joueur cible",
			Optional = true,
		},
	},
}
