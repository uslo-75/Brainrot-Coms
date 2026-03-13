return {
	Name = "SetMutation",
	Aliases = {"sm", "mutbr"},
	Description = "Changer la mutation d'un brainrot",
	Group = "Admin",
	Args = {
		{
			Type = "number",
			Name = "Position",
			Description = "Slot du brainrot",
		},
		{
			Type = "brairotMutation",
			Name = "Mutation",
			Description = "Nouvelle mutation",
		},
		{
			Type = "player",
			Name = "Player",
			Description = "Joueur cible",
			Optional = true,
		},
	},
}
