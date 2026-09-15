--!strict

local types = require(script.Parent.Parent.ItemConfigTypes)

local config: types.LanternConfig = {
	displayName = "Lantern",
	description = "A broad light source that can be carried in one hand.",
	imageId = 138236954962919,
	controllerClass = "Lantern" :: "Lantern",
	persistentAttributes = {},
	stack = nil,
	rigging = {
		{
			isWeld = false,
			part0 = "Right Arm",
			part1 = "Handle",
			c0 = CFrame.new(-0.387, -1, 0),
			c1 = CFrame.identity,
		},
	},

	cooldownTimeSeconds = 0.35,

	viewModel = {
		armFollow = true,
		handFollow = false,
		leftArmSupportEnabled = false,

		rightArm = {
			baseOffset = Vector3.new(0.7, 0, 0),

			firstPersonViewmodel = {
				maximumLookUpRadians = math.rad(70),
				maximumLookDownRadians = math.rad(55),
				lookUpPitchScale = 0.85,
				lookDownPitchScale = 0.85,
				lookUpOffset = Vector3.new(-0.25, -0.8, 0),
				lookDownOffset = Vector3.new(0, 0.12, 0.04),
			},

			firstPersonTurnResponse = {
				turnDepthAlpha = 0.35,
				turnLateralAlpha = 0.25,
				turnDepthStuds = 0,
				turnLateralStuds = 2,
				overshootSlideFactor = 1.5,
				verticalOvershootHeightScale = 0.2,
				maximumVerticalOvershootRadians = math.rad(90),
			},
		},
	},

	animations = {
		idle = 87837642565948,
		equip = 125561521074918,
		unequip = 126068478756046,
		on = 71203042255521,
		off = 109645770672286,
	},
	holsterDurationSeconds = 1, -- = unequip track length (verify on re-time)
}

return config
