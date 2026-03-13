return {
	Name = "ReturnMachine",
	Aliases = {"rtm", "returnbr"},
	Description = "Retirer un brainrot d'une machine et le remettre normal sur son slot",
	Group = "Admin",
	Args = {
		{
			Type = "number",
			Name = "Position",
			Description = "Slot du brainrot a restaurer",
		},
		{
			Type = "player",
			Name = "Player",
			Description = "Joueur cible",
			Optional = true,
		},
	},
}
