local configuration = {}

configuration.shared = {
	ranges = {
		chase = 80,
		stalk = 110,
		attack = 6,

		registerNear = 15,

		circling = {
			min = 50,
			max = 70,
		},
	},

	walkSpeeds = {
		walk = 7,
		run = 15,
		scream = 8,
		sneak = 6,
	},

	cooldowns = {
		attack = 0.5,
	},
}

configuration.animations = {
	idle = 91911404139685,

	walk = {
		sneakForward = 120936534459461,
		searchForward = 134476177397476,
		forward = 138340826216902,
		backward = 71342069958249,
		left = 135111128204982,
		right = 86309813408426,
	},

	run = {
		nearTargetForward = 138049571428866,
		forward = 106628483628764,
		backward = 97591881178486,
		left = 80884704586875,
		right = 77062389220711,
	},

	search = {
		casual = 84781397261931,
		aggressive = 92280816694531,
	},

	lightAttack = {
		[1] = 116880911037117,
		[2] = 82926638224867,
	},

	heavyAttack = {
		[1] = 78211675816738,
		[2] = 98201334088415,
	},

	scream = 113328110305015,
}

return configuration
