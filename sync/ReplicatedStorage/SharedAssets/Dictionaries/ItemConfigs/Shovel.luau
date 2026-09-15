--!strict

local types = require(script.Parent.Parent.ItemConfigTypes)

local config: types.MeleeConfig = {
	displayName = "Shovel",
	description = "A full-sized shovel that doubles as a blunt weapon.",
	imageId = 104782145119988,
	controllerClass = "Melee" :: "Melee",
	persistentAttributes = {},
	stack = nil,

	rigging = {
		{
			part0 = "Left Arm",
			part1 = "Handle",
			c0 = CFrame.new(0.259, -0.799, 0),
			c1 = CFrame.identity,
		},
	},

	damage = { min = 25, max = 35 },
	staminaCost = { min = 20, max = 30 },
	hitboxSize = Vector3.one * 5,
	hitboxDelayTime = 0.11,
	swingLastingTime = 0.6,
	cooldownTime = 2,
	chargeHoldDuration = 1.64,
	chargeDepleteDuration = 4.4,
	chargeDepleteWaitTime = 1.2,
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
		idle = 73723323544606,
		equip = 88394102372886,
		chargeStart = 124325428700274,
		chargeLoop = 98995686865489,
		swing = 96628846635405,
		heavySwing = 87830459722280,
		unequip = 127146942646031,
	},
	holsterDurationSeconds = 2.25, -- = unequip track length (verify on re-time)

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
}

return config
