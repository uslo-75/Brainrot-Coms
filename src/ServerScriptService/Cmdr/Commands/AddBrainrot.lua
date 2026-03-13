return {
	Name = "AddBrainrot",
	Aliases = {"ABD"},
	Description = "Ajouter un brainrot dans une base",
	Group = "Admin",
	Args = {
		{
			Type = "brairotName",
			Name = "BrairotName",
			Description = "Nom du brainrot a ajouter",
		},
		{
			Type = "brairotMutation",
			Name = "Mutation",
			Description = "Mutation a appliquer",
		},
		{
			Type = "number",
			Name = "Slots",
			Description = "Nombre de slots d'aura a creer",
			Optional = true,
		},
		{
			Type = "player",
			Name = "Player",
			Description = "Joueur cible",
			Optional = true,
		},
	},
}
