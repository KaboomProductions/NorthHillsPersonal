--!strict

local types = require(script.Parent.Parent.ItemConfigTypes)

local config: types.MeleeConfig = {
	displayName = "Tomahawk",
	description = "A light axe with a quick, sharp swing.",
	imageId = 87782620460394,
	controllerClass = "Melee" :: "Melee",
	persistentAttributes = {},
	stack = nil,

	rigging = {
		{
			part0 = "Right Arm",
			part1 = "Handle",
			c0 = CFrame.new(-0.333, -0.737, 0),
			c1 = CFrame.new(-0.056, 0.013, 0),
		},
	},

	damage = { min = 20, max = 40 },
	staminaCost = { min = 10, max = 20 },
	hitboxSize = Vector3.one * 5,
	hitboxDelayTime = 0.11,
	swingLastingTime = 0.6,
	cooldownTime = 2,
	chargeHoldDuration = 1.67,
	chargeDepleteDuration = 7,
	chargeDepleteWaitTime = 2,
	maxCharge = 100,
	chargeBarLerpSpeed = 7,
	chargeBarTransparencyThreshold = 0.001,

	hitbox = {
		delayTimeSeconds = 0.11,
		lastingTimeSeconds = 0.6,
	},

	cooldownTimeSeconds = 2,
	staminaUsage = 15,
	weaponType = "Sharp",

	animations = {
		idle = 119017423523546,
		equip = 100803759166066,
		chargeStart = 129662240382259,
		chargeLoop = 72327720884233,
		swing = 77602464035349,
		unequip = 112230937699074,
	},
	holsterDurationSeconds = 1.2, -- = unequip track length (verify on re-time)

	viewModel = {
		armFollow = true,
		handFollow = false,
		leftArmSupportEnabled = false,

		rightArm = {
			baseOffset = Vector3.new(0.5, 0, 0),

			firstPersonViewmodel = {
				maximumLookUpRadians = math.rad(90),
				maximumLookDownRadians = math.rad(55),
				lookUpPitchScale = 0.85,
				lookDownPitchScale = 0.55,
				lookUpOffset = Vector3.new(-0.5, 0.45, 0),
				lookDownOffset = Vector3.new(0, 0.12, 0.04),
			},

			firstPersonTurnResponse = {
				turnDepthAlpha = 0.35,
				turnLateralAlpha = 0.25,
				turnDepthStuds = 2,
				turnLateralStuds = 2,
				overshootSlideFactor = 1.5,
				verticalOvershootHeightScale = 0.2,
				maximumVerticalOvershootRadians = math.rad(90),
			},
		},
	},
}

return config
