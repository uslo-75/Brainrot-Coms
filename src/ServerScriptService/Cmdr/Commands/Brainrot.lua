return {
	Name = "Brainrot",
	Aliases = {"br", "BR"},
	Description = "Gerer les auras d'un brainrot",
	Group = "Admin",
	Args = {
		{
			Type = "number",
			Name = "Position",
			Description = "Position du brainrot a modifier",
		},
		{
			Type = "string",
			Name = "AurasNames",
			Description = "Auras ou slots selon le type choisi",
		},
		{
			Type = "typesList",
			Name = "Types",
			Description = "Mode: Default, Delete, All ou AllDelete",
			Optional = true,
		},
		{
			Type = "player",
			Name = "Player",
			Description = "Joueur cible, sinon l'executant",
			Optional = true,
		},
	},
}
