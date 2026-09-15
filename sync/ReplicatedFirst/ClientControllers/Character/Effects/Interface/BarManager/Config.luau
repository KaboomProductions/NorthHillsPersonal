local barManagerConfig = {
	stateValues = {
		hiddenYScale = 1.2,
		firstSlotYScale = 0.897,
		slotStep = 0.09,
		hideDelaySeconds = 5,
		startupIgnoreSeconds = 1,

		positionSpring = {
			frequency = 15,
			damping = 100,
			mass = 4,
			speed = 2.3,
		},

		transparencyLerpSpeed = 12,
		hiddenTransparency = 1,
		visibleTransparency = 0,
		positionSettleThreshold = 0.002,
		transparencySettleThreshold = 0.02,
		isShopOpen = false,
	},

	priorityByBarName = {
		Health = 1,
		Stamina = 2,
	},
}

return barManagerConfig
