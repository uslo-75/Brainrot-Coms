local GameConfig = {
	-- Generic place label used by shared systems.
	PlaceName = "RollABrainrot",
	-- Enables optional debug behaviors when a script checks it.
	Debug = true,
	-- Default round length for systems that need a fallback value.
	RoundDuration = 90,

	Shared = {
		-- Default timeout for non-critical WaitForChild helper loops.
		DefaultWaitTimeout = 15,
	},

	Preview = {
		-- Max seconds the client waits for a preview model to replicate.
		ClientTimeout = 10,
		-- Max length accepted for a preview cache key sent by the client.
		KeyMaxLength = 120,
		-- Max length accepted for a preview model name sent by the client.
		NameMaxLength = 80,
	},

	Data = {
		-- Default saved music percentage for a fresh or invalid profile.
		DefaultMusic = 50,
		-- Lowest allowed saved music percentage.
		MusicMin = 0,
		-- Highest allowed saved music percentage.
		MusicMax = 100,
		-- Highest allowed SkipBrainrot threshold saved per player.
		MaxSkipBrainrot = 1e15,
	},

	Prompts = {
		-- Client refresh interval used to recompute prompt visibility.
		RefreshInterval = 0.08,

		BaseSlot = {
			-- Vertical offset of the place prompt above a base slot.
			VerticalOffset = 5.5,
			-- Forward offset of the place prompt in front of a base slot.
			ForwardOffset = -6,
			-- Max interaction distance for base-slot place prompts.
			MaxActivationDistance = 8,
		},

		Drop = {
			-- Base vertical offset applied to dropped brainrot prompts.
			BaseHeight = 2.5,
			-- Extra height taken from the hitbox size multiplier.
			HeightHitboxScale = 0.15,
			-- Max extra height allowed from the hitbox size.
			HeightHitboxMax = 3,
			-- Base forward distance applied to dropped brainrot prompts.
			BaseDistance = 3.5,
			-- Max extra forward distance allowed from the hitbox depth.
			DistanceHitboxMax = 8,
			-- Base activation distance for dropped brainrot prompts.
			BaseActivationDistance = 14,
			-- Rarity-specific prompt bonuses for larger dropped models.
			RarityBonuses = {
				Secret = {
					Height = 1.5,
					ActivationDistance = 6,
					ForwardDistance = 4,
				},
				["Brainrot God"] = {
					Height = 1,
					ActivationDistance = 4,
					ForwardDistance = 2.5,
				},
			},
		},
	},

	Music = {
		-- Default lobby playlist folder stored in SoundService.
		DefaultPlaylistFolder = "Playlist",
		-- Accepted folder names for the disco event playlist.
		DiscoPlaylistFolders = { "DiscoMusics", "Disco Musics" },
		-- Delay before a song start is treated as stalled and retried.
		SongStallTimeout = 0.75,
	},

	MapMutation = {
		-- Extra server luck multiplier applied while a map event is active.
		ServerLuckMultiplier = 4,
		-- Duration in seconds of the map event luck boost.
		ServerLuckDuration = 600,
		-- Small delay used when swapping runtime map content and lighting.
		TransitionDelay = 0.1,

		Positions = {
			-- Runtime pivot target for the BubbleGum map.
			BubbleGum = Vector3.new(-0.047, 21.842, -0.02),
			-- Runtime pivot target for the Freeze map.
			Freeze = Vector3.new(-1.377, 63.441, 0.002),
			-- Runtime pivot target for the Solar map.
			Solar = Vector3.new(3.477, 14.509, -0.421),
			-- Runtime pivot target for the Spectral map.
			Spectral = Vector3.new(0.049, 17.831, -2.947),
			-- Runtime pivot target for the Volcan map.
			Volcan = Vector3.new(0.021, 26.696, -0.076),
		},

		AdminAbusePositions = {
			-- Runtime pivot target for the Disco admin abuse map.
			Disco = Vector3.new(-0.047, 58.105, -0.02),
		},
	},

	ServerLuck = {
		-- Attribute that stores the active map-event luck multiplier.
		MapMutationLuckAttribute = "MapMutationLuckMultiplier",
		-- Attribute that stores the active map-event remaining time.
		MapMutationTimeAttribute = "MapMutationLuckTime",
		-- Base multiplier used when no server-wide luck boost is active.
		DefaultBaseMultiplier = 1,
		-- Portion of base luck kept when map luck stacks on top of it.
		MapStackBonusFactor = 0.5,
	},

	Disco = {
		-- Workspace folder used for temporary disco sky-drop models.
		RuntimeFolderName = "DiscoSkyDrops",
		-- Name of the disco ball model inside the runtime map.
		BallName = "DiscoBall",
		-- Prefix used to auto-detect disco NPC rigs in the map.
		RigPrefix = "Disco ",
		-- Rotation speed of the disco ball in degrees per second.
		BallRotationSpeedDegrees = 45,
		-- Delay between retry scans when disco rigs are not ready yet.
		RigRetryInterval = 2,
		-- Vertical spawn height used for disco sky drops.
		FallHeight = 110,
		-- Percent of the runtime map width used as the drop radius.
		DropRadiusScale = 0.22,
		-- Smallest allowed drop radius around the map center.
		DropRadiusMin = 12,
		-- Largest allowed drop radius around the map center.
		DropRadiusMax = 34,
		-- Fastest travel time for a brainrot falling from the sky.
		DropFallTimeMin = 2.75,
		-- Slowest travel time for a brainrot falling from the sky.
		DropFallTimeMax = 4.5,
		-- Minimum delay between two disco sky drops.
		DropIntervalMin = 12,
		-- Maximum delay between two disco sky drops.
		DropIntervalMax = 24,
		-- Maximum number of disco drops kept alive at once.
		MaxActiveDrops = 5,
		-- Time in seconds before an unclaimed disco drop despawns.
		DropLifetime = 120,
		-- Weighted slot counts used when building a disco drop.
		SlotWeights = {
			{ Count = 1, Weight = 35 }, -- Most common single-slot drop.
			{ Count = 2, Weight = 30 }, -- Common two-slot drop.
			{ Count = 3, Weight = 20 }, -- Mid-tier three-slot drop.
			{ Count = 4, Weight = 10 }, -- Rare four-slot drop.
			{ Count = 5, Weight = 5 }, -- Rarest five-slot drop.
		},
		-- Only these rarities are allowed for disco sky drops.
		AllowedRarities = {
			Mythic = true,
			["Brainrot God"] = true,
			Secret = true,
		},
		-- Preferred landing-surface names used by disco drop raycasts.
		GroundNames = {
			ground = true,
			floor = true,
			baseplate = true,
			dancefloor = true,
		},
	},
}

return GameConfig
