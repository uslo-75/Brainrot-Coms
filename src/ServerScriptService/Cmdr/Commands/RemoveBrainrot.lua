return {
	Name = "RemoveBrainrot",
	Aliases = {"rmb", "delbr"},
	Description = "Supprimer un brainrot d'un slot",
	Group = "Admin",
	Args = {
		{
			Type = "number",
			Name = "Position",
			Description = "Slot a vider",
		},
		{
			Type = "player",
			Name = "Player",
			Description = "Joueur cible",
			Optional = true,
		},
	},
}
