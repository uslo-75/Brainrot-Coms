return {
	Name = "SetFuseTimeGlobal",
	Aliases = { "globalfusetime", "gfuse", "gfusetime" },
	Description = "Definir globalement le temps restant de toutes les fusions actives.",
	Group = "Admin",
	Args = {
		{
			Type = "number",
			Name = "Seconds",
			Description = "Temps restant en secondes. 0 termine instantanement les fusions.",
		},
	},
}
