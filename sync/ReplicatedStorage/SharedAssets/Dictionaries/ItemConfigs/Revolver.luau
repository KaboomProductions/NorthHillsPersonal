--!strict

local types = require(script.Parent.Parent.ItemConfigTypes)

local config: types.GunConfig = {
	displayName = "Revolver",
	description = "A light axe with a quick, sharp swing.",
	imageId = 87782620460394,
	controllerClass = "Gun" :: "Gun",
	persistentAttributes = {},
	stack = nil,
	holsterDurationSeconds = nil,

	rigging = {
		{
			part0 = "Right Arm",
			part1 = "Handle",
			c0 = CFrame.new(-0.363, -0.628, -0.433),
			c1 = CFrame.identity,
		},
	},

	projectileObjectId = "Tracer",
	projectileClassId = "Bullet",
	maxAmmo = 8,
	startingReserveAmmo = 8,

	damage = { min = 20, max = 40 },
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

	hitbox = {
		delayTimeSeconds = 0.11,
		lastingTimeSeconds = 0.6,
	},

	cooldownTimeSeconds = 2,
	staminaUsage = 15,
	weaponType = "Sharp",

	animations = {
		idle = 105577542273710,
		equip = 86799826694291,
		hammer = 94161138156409,
		dryfire = 127149734680680,
		shoot = 76487527203186,
		reload = 75295840322038,
	},

	viewModel = {
		armFollow = true,
		handFollow = false,
		cameraRelative = true,
		cameraRelativeAim = true,
		cameraRelativeLookDown = {
			maximumAngleRadians = math.rad(55),
			offsetStuds = 0.3,
		},
		cameraRelativeLookUp = {
			maximumAngleRadians = math.rad(55),
			offsetStuds = 0.35,
		},
		aim = {
			fieldOfViewOffset = -15,
			blendDurationSeconds = 0.18,
		},
		recoil = {
			positionVelocity = Vector3.new(0, 0.12, 8),
			positionVelocityVariation = Vector3.new(0.08, 0.05, 0.18),
			rotationVelocityRadians = Vector3.new(0, 0, 0),
			rotationVelocityVariationRadians = Vector3.new(math.rad(7), math.rad(10), math.rad(4)),
			aimingMultiplier = 0.72,
			spring = {
				mass = 2,
				force = 85,
				damping = 5,
				speed = 3,
			},
			camera = {
				rotationVelocityRadians = Vector3.new(math.rad(52), 0, 0),
				rotationVelocityVariationRadians = Vector3.new(math.rad(4), 0, 0),
				settledPitchIncrementRadians = math.rad(5.5),
				settledPitchVariationRadians = math.rad(0.15),
				aimingMultiplier = 0.7,
				spring = {
					mass = 5,
					force = 125,
					damping = 5,
					speed = 3.2,
				},
			},
		},
		leftArmSupportEnabled = true,
		coupledArms = true,
		rightArm = {
			baseOffset = Vector3.new(0.5, -0.1, 0),
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
		leftArmSupport = {
			offset = Vector3.zero,
			rotationRadians = Vector3.zero,
			followsRightArm = true,
		},
	},
}

return config
