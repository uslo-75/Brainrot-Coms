return {
	Name = "RestartServer",
	Aliases = { "restart", "shutdown", "rs" },
	Description = "Restart le serveur actuel ou tous les serveurs",
	Group = "Admin",
	Args = {
		{
			Type = "mapMutationScope",
			Name = "Scope",
			Description = "Local ou Global",
			Optional = true,
		},
	},
}
