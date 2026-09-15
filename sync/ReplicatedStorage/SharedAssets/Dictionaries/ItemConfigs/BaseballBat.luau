--!strict

local types = require(script.Parent.Parent.ItemConfigTypes)

local config: types.MeleeConfig = {
	displayName = "Baseball Bat",
	description = "A dependable blunt weapon that can also be thrown.",
	imageId = 104782145119988,
	controllerClass = "Melee" :: "Melee",
	persistentAttributes = {},
	stack = nil,
	throwable = {
		projectileId = "ThrownBat",
		velocity = 60,
		releaseTimeoutSeconds = 0.75,
		animationId = nil,
		releaseMarker = "Release",
	},
	upgrades = {
		{
			id = "spiked",
			resultItemType = "SpikedBat",
			materials = {
				{ materialType = "Nails", count = 5 },
				{ materialType = "DuctTape", count = 1 },
			},
		},
	},

	rigging = {
		{
			part0 = "Right Arm",
			part1 = "Handle",

			c0 = CFrame.new(-0.023, -0.994, 0.013) * CFrame.Angles(math.rad(-90), 0, 0),
			c1 = CFrame.new(0, -0.1, -0.1),
		},
	},

	damage = {
		min = 15,
		max = 25,
	},
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

	animations = {
		idle = 126836156409356,
		equip = 74231875433032,
		swing = 123554086665673,
	},
	holsterDurationSeconds = 0, -- = unequip track length (verify on re-time)
}

return config
