return {
	Name = "LuckServer",
	Aliases = {"LS", "ls"},
	Description = "Envoyer un buff de luck global au serveur",
	Group = "Admin",
	Args = {
		{
			Type = "number",
			Name = "LuckBuff",
			Description = "Multiplicateur de luck global",
		},
		{
			Type = "number",
			Name = "Time",
			Description = "Duree du buff en secondes",
			Optional = true,
		},
	},
}
