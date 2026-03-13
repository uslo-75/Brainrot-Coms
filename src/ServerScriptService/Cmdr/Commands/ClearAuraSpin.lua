return {
	Name = "ClearAuraSpin",
	Aliases = {"cas", "clearaura"},
	Description = "Vider l'Aura Spin d'un joueur",
	Group = "Admin",
	Args = {
		{
			Type = "player",
			Name = "Player",
			Description = "Joueur cible",
			Optional = true,
		},
	},
}
