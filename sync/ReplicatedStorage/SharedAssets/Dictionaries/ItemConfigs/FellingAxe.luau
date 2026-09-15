--!strict

local types = require(script.Parent.Parent.ItemConfigTypes)

local config: types.MeleeConfig = {
	displayName = "Felling Axe",
	description = "A long-handled axe made for powerful two-handed strikes.",
	imageId = 77381048900816,
	controllerClass = "Melee" :: "Melee",
	persistentAttributes = {},
	stack = nil,

	rigging = {
		{
			part0 = "Left Arm",
			part1 = "Handle",
			c0 = CFrame.new(0.19, -0.851, 0),
			c1 = CFrame.identity,
		},
	},

	damage = {
		min = 20,
		max = 40,
	},
	staminaCost = { min = 10, max = 20 },
	hitboxSize = Vector3.one * 5,
	hitboxDelayTime = 0.11,
	swingLastingTime = 0.6,
	cooldownTime = 2,
	chargeHoldDuration = 2,
	chargeDepleteDuration = 5,
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

	viewModel = {
		armFollow = true,
		handFollow = false,
		leftArmSupportEnabled = true,
		coupledArms = true,

		rightArm = {
			baseOffset = Vector3.new(0.5, 0, 0),

			firstPersonViewmodel = {
				maximumLookUpRadians = math.rad(70),
				maximumLookDownRadians = math.rad(35),
				lookUpPitchScale = 0.55,
				lookDownPitchScale = 0.55,
				lookUpOffset = Vector3.new(0, -0.8, -0.5),
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

		leftArmSupport = {
			offset = Vector3.zero,
			rotationRadians = Vector3.zero,
			followsRightArm = true,
		},
	},

	animations = {
		idle = 140308512314262,
		equip = 104470989034114,
		chargeStart = 111784567875856,
		chargeLoop = 108595371458299,
		swing = 120394060550928,
		heavySwing = 96213793936211,
		unequip = 130620637755361,
	},
	holsterDurationSeconds = 3.6, -- = unequip track length (verify on re-time)
}

return config
