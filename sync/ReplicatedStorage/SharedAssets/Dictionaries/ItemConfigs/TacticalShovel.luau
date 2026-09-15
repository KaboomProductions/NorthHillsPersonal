--!strict

local types = require(script.Parent.Parent.ItemConfigTypes)

local config: types.MeleeConfig = {
	displayName = "Tactical Shovel",
	description = "A compact shovel balanced for close combat.",
	imageId = 104782145119988,
	controllerClass = "Melee" :: "Melee",
	persistentAttributes = {},
	stack = nil,

	rigging = {
		{
			part0 = "Right Arm",
			part1 = "Handle",
			c0 = CFrame.new(-0.294, -0.758, 0),
			c1 = CFrame.identity,
		},
	},

	damage = { min = 15, max = 30 },
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
		idle = 72228308413481,
		equip = 137735032412867,
		specialEquip = 113546888690612,
		chargeStart = 119629773216614,
		chargeLoop = 103360677953316,
		swing = 90922904442062,
		heavySwing = 83470621641786,
		unequip = 97834070162294,
	},
	holsterDurationSeconds = 1.25, -- = unequip track length (verify on re-time)
	throwable = {
		projectileId = "ThrownBat",
		velocity = 60,
		releaseTimeoutSeconds = 0.75,
		animationId = nil,
		releaseMarker = "Release",
	},

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
