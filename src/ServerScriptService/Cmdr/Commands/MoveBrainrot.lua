return {
	Name = "MoveBrainrot",
	Aliases = {"mbr", "swapbr"},
	Description = "Deplacer ou echanger un brainrot entre deux slots",
	Group = "Admin",
	Args = {
		{
			Type = "number",
			Name = "FromPosition",
			Description = "Slot source",
		},
		{
			Type = "number",
			Name = "ToPosition",
			Description = "Slot destination",
		},
		{
			Type = "player",
			Name = "Player",
			Description = "Joueur cible",
			Optional = true,
		},
	},
}
