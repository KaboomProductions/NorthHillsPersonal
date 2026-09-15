return {
	raycastRange = 1000,
	clutterCleanRate = 10,
	debugMode = false,

	positioning = {
		min = 180,
		max = 90,
	},

	stages = {
		[1] = {
			updateRate = 0.001,

			textures = {
				102417649464392,
				76008155618983,
				119298596862930,
			},

			settings = {
				ystuds = 50,

				offset = {
					min = -0.2,
					max = 0.2,
				},

				tweenDuration = {
					min = 2,
					max = 6,
				},

				beam = {
					width = {
						min = 2,
						max = 4,
					},

					curve0 = {
						min = -5,
						max = 10,
					},

					textureSpeed = {
						min = 1,
						max = 3,
					},

					textureLength = {
						min = 3,
						max = 6,
					},
				},
			},
		},
	},
}
