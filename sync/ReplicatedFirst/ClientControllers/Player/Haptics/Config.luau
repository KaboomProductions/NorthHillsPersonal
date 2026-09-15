local hapticConfig = {
	effectsByChannel = {
		camera = { name = "CameraHaptic", position = Vector3.zero, radius = 1.1 },
		chaseAmbient = { name = "ChaseAmbientHaptic", position = Vector3.zero, radius = 3 },
		chaseImpulse = { name = "ChaseImpulseHaptic", position = Vector3.zero, radius = 3 },
		damage = { name = "DamageHaptic", position = Vector3.zero, radius = 3 },
		health = { name = "HealthHaptic", position = Vector3.zero, radius = 3 },
		interface = { name = "InterfaceHaptic", position = Vector3.zero, radius = 3 },
		meleeCharge = { name = "MeleeChargeHaptic", position = Vector3.new(2, 0, 0), radius = 1.1 },
		meleeImpulse = { name = "MeleeImpulseHaptic", position = Vector3.new(0.8, 0, 0), radius = 1.1 },
		movement = { name = "MovementHaptic", position = Vector3.zero, radius = 1.1 },
		stamina = { name = "StaminaHaptic", position = Vector3.zero, radius = 1.1 },
		staminaImpulse = { name = "StaminaImpulseHaptic", position = Vector3.zero, radius = 1.1 },
		tool = { name = "ToolHaptic", position = Vector3.new(0.65, 0, 0), radius = 1.1 },
	},
	persistentUrgencySteps = 20,

	damage = {
		fullIntensityDamageFraction = 0.5,
		minimumIntensity = 0.15,
		maximumIntensity = 1,
		minimumDurationSeconds = 0.14,
		maximumDurationSeconds = 0.45,
	},

	ui = {
		hover = {
			intensity = 0.2,
			durationSeconds = 0.05,
		},

		click = {
			intensity = 0.55,
			durationSeconds = 0.11,
		},

		slider = {
			minimumIntensity = 0.001,
			maximumIntensity = 0.28,
			intensityExponent = 2,
			durationSeconds = 0.04,

			boundaryIntensity = 0.85,
			boundaryDurationSeconds = 0.09,
		},

		hotbar = {
			intensity = 0.16,
			durationSeconds = 0.055,
		},
	},

	perspective = {
		intensity = 0.26,
		durationSeconds = 0.02,
	},

	toolToggle = {
		intensity = 0.2,
		durationSeconds = 0.02,
	},

	movement = {
		sprint = {
			intensity = 0.22,
			durationSeconds = 0.02,
		},

		crouch = {
			intensity = 0.13,
			durationSeconds = 0.02,
		},
	},

	health = {
		activationHealth = 50,
		minimumIntensity = 0.09,
		maximumIntensity = 0.32,
		waveformDurationSeconds = 1.1,
		variationFraction = 0.12,
	},

	stamina = {
		activationFraction = 0.5,
		minimumIntensity = 0.035,
		maximumIntensity = 0.12,
		waveformDurationSeconds = 1.35,
		variationFraction = 0.16,

		depleted = {
			intensity = 0.56,
			durationSeconds = 0.28,
		},
	},

	chase = {
		minimumDistanceStuds = 10,
		minimumIntensity = 0.005,
		maximumIntensity = 0.01,
		combatIntensityMultiplier = 0.42,
		waveformDurationSeconds = 0.8,
		variationFraction = 0.1,

		started = {
			intensity = 0.2,
			durationSeconds = 0.36,
		},
	},

	melee = {
		charge = {
			minimumIntensity = 0,
			maximumIntensity = 5,
		},

		release = {
			minimumIntensity = 0.42,
			maximumIntensity = 0.8,
			minimumDurationSeconds = 0.08,
			maximumDurationSeconds = 0.14,
		},

		impact = {
			minimumIntensity = 0.7,
			maximumIntensity = 1,
			minimumDurationSeconds = 0.11,
			maximumDurationSeconds = 0.18,
		},
	},
}

return hapticConfig
