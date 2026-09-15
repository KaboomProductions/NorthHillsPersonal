--!strict

local types = require(script.Parent.Parent.ItemConfigTypes)

local config: types.FlashlightConfig = {
	displayName = "Flashlight",
	description = "A handheld light for dark interiors.",
	imageId = 81069640059406,
	controllerClass = "Flashlight" :: "Flashlight",
	persistentAttributes = {},
	stack = nil,
	rigging = {
		{
			isWeld = true,
			part0 = "Right Arm",
			part1 = "Handle",
			c0 = CFrame.new(0, -1, 0) * CFrame.Angles(math.rad(-90), 0, 0),
			c1 = CFrame.new(0, 0, 0.193) * CFrame.Angles(math.rad(90), 0, 0),
		},
	},

	cooldownTimeSeconds = 0.35,

	viewModel = {
		armFollow = true,
		handFollow = true,
		leftArmSupportEnabled = false,

		rightArm = {
			baseOffset = Vector3.new(0.4, 0, 0),

			firstPersonViewmodel = {
				maximumLookUpRadians = math.rad(70),
				maximumLookDownRadians = math.rad(55),
				lookUpPitchScale = 0.55,
				lookDownPitchScale = 0.85,
				lookUpOffset = Vector3.new(-0.25, -0.8, 0),
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
			offset = Vector3.new(0, 0, -3),
			rotationRadians = Vector3.new(0, math.rad(180), 0),
			followsRightArm = false,
		},
	},

	animations = {
		idle = 80379385986123,
		equip = 115864702009596,
		unequip = 94480239734496,
		toggle = 133524813391883,
	},
	holsterDurationSeconds = 0.7, -- = unequip track length (verify on re-time)
}

return config
