return {
	Name = "SetFuseTime",
	Aliases = { "fusetime", "finishfuse", "fusefinish" },
	Description = "Definir le temps restant d'une fusion active. 0 termine instantanement.",
	Group = "Admin",
	Args = {
		{
			Type = "number",
			Name = "Seconds",
			Description = "Temps restant en secondes. 0 termine la fusion.",
		},
		{
			Type = "player",
			Name = "Player",
			Description = "Joueur cible",
			Optional = true,
		},
	},
}
