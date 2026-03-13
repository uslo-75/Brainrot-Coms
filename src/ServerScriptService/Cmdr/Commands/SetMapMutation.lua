return {
	Name = "SetMapMutation",
	Aliases = { "smm", "mapmut" },
	Description = "Changer la map et le lighting du serveur selon une mutation",
	Group = "Admin",
	Args = {
		{
			Type = "mapMutation",
			Name = "Mutation",
			Description = "Mutation de map a appliquer",
		},
		{
			Type = "mapMutationScope",
			Name = "Scope",
			Description = "Local ou Global",
		},
	},
}
