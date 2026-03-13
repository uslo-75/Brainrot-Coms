return {
	Name = "AdminAbuse",
	Aliases = { "aa" },
	Description = "Active un mode special d'admin abuse sur la map",
	Group = "Admin",
	Args = {
		{
			Type = "adminAbuse",
			Name = "Mode",
			Description = "Type d'admin abuse a appliquer",
		},
		{
			Type = "mapMutationScope",
			Name = "Scope",
			Description = "Local ou Global",
		},
	},
}
