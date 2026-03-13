return {
	
	MaxMultiplicater = 2,
	PushOnCancel = true,
	
	PunshVelocity = {
		Forward = 50,
		Up = 50,
	},
	
	Combats = {
		
		Combo = 0,
		LastAttackTime = 0,
		PunchCooldown = 0.1,
		PunchReset = 0.75,
		MaxCombo = 4,
		
		TimeToFeint = 0.25,
		blockCooldown = 0.5,
	},

	Run = {
		Normal = 16,
		Extra = 44,
		MaxTicksWTap = 0.2,
		RunCooldown = 0,
		LastTime = tick(),
	},

	Roll = {
		Cooldown = 1,
		Power = 42,
	},

	Sliding = {
		Cooldown = 2.5,
		Power = 55,
		Length = 5,
	},
	
	SpeedChangeRate = {
		Forward = 1,
		Upward = 2,
		Downward = 1,
	},
	
	
	HipHeight = {
		Normal = 0,
		Slide = -2,
	},

	Landing = {
		Height = 6.5,
		MaxVaultHeight = 4,
	},

	Climb = {
		Cooldown = 0.5,
		Force = 30,
		Decay = 1,
	},

	DoubleJump = {
		Cooldown = 2,
		Power = 40,
		Decay = 2,
	},

	FallDamage = {
		Factor = 2,
	},

	Camera = {
		MaxTiltAngle = 1,
		MinFOV = 70,
		MaxFOV = 75,
	},
	
	WallRun = {
		WallRunDuration = 3,
		WallJumpOutForce = 20,
		WallJumpUpForce = 28,
		WallRunSpeed = 22,
		GravityMultiplier = 0.2,
		WallDistance = 3,
	},
	
}