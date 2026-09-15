local animationConfig = {
	hoverScale = 1.02,
	pressedScale = 0.98,
	baseScale = 1,

	springMass = 15,
	springForce = 150,
	springDamping = 4,
	springSpeed = 5.3,

	activeTransparency = 0,
	defaultInactiveTransparency = 0.6,
	featherSize = 0.3,
	waveLerpDecay = 0.0001,
	waveSettleDistance = 0.002,

	leftOffset = Vector2.new(-1, 0),
	rightOffset = Vector2.new(1, 0),
}

return animationConfig
