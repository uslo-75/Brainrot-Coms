return {
	Name = "PrintBrainrot",
	Aliases = {"pbr", "brainrotinfo"},
	Description = "Afficher l'etat detaille d'un brainrot",
	Group = "Admin",
	Args = {
		{
			Type = "number",
			Name = "Position",
			Description = "Slot a inspecter",
		},
		{
			Type = "player",
			Name = "Player",
			Description = "Joueur cible",
			Optional = true,
		},
	},
}
