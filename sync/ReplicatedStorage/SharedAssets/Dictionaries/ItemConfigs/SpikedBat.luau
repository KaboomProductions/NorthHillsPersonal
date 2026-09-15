--!strict

local types = require(script.Parent.Parent.ItemConfigTypes)

local config: types.MeleeConfig = {
	displayName = "Spiked Bat",
	description = "A baseball bat reinforced with nails and duct tape.",
	imageId = 104782145119988,
	controllerClass = "Melee" :: "Melee",
	persistentAttributes = {},
	stack = nil,
	throwable = nil,
	upgrades = nil,

	rigging = {
		{
			part0 = "Right Arm",
			part1 = "Handle",
			c0 = CFrame.new(-0.023, -0.994, 0.013) * CFrame.Angles(math.rad(-90), 0, 0),
			c1 = CFrame.new(0, -0.1, -0.1),
		},
	},

	damage = { min = 25, max = 40 },
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
	weaponType = "Blunt",

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
		idle = 126836156409356,
		equip = 74231875433032,
		swing = 123554086665673,
	},
	holsterDurationSeconds = 0, -- = unequip track length (verify on re-time)
}

return config
