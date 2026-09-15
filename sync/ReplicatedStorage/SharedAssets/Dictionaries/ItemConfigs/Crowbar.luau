--!strict

local types = require(script.Parent.Parent.ItemConfigTypes)

local config: types.MeleeConfig = {
	displayName = "Crowbar",
	description = "A heavy steel bar suited for close combat.",
	imageId = 108670330407583,
	controllerClass = "Melee" :: "Melee",
	persistentAttributes = {},
	stack = nil,

	rigging = {
		{
			part0 = "Left Arm",
			part1 = "Handle",

			c0 = CFrame.new(0.263, -0.781, 0),
			c1 = CFrame.identity,
		},
	},

	damage = {
		min = 25,
		max = 35,
	},
	staminaCost = { min = 10, max = 20 },
	hitboxSize = Vector3.one * 5,
	hitboxDelayTime = 0.11,
	swingLastingTime = 0.6,
	cooldownTime = 2,
	chargeHoldDuration = 1.6,
	chargeDepleteDuration = 5.4,
	chargeDepleteWaitTime = 1.8,
	maxCharge = 100,
	chargeBarLerpSpeed = 7,
	chargeBarTransparencyThreshold = 0.001,

	--// Markers were unreliable for client-server animation communication.
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
		idle = 74140745511993,
		equip = 125609613580987,
		chargeStart = 83939424390065,
		chargeLoop = 83694510500211,
		swing = 98922905510735,
		heavySwing = 98487612919266,
		unequip = 81825102446895,
	},
	holsterDurationSeconds = 1.95, -- = unequip track length (verify on re-time)
}

return config
