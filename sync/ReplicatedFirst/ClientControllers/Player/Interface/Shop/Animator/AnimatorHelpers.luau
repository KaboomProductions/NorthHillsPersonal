local animatorHelper = {}

function animatorHelper.isSpringSettled(spring, target: Vector2, positionEpsilon: number?, velocityEpsilon: number?): boolean
	positionEpsilon = positionEpsilon or 0.1
	velocityEpsilon = velocityEpsilon or 0.1
	return (spring.position - target).Magnitude < positionEpsilon and spring.velocity.Magnitude < velocityEpsilon
end

function animatorHelper.isUdim2Settled(current: UDim2, target: UDim2, scaleEpsilon: number?, offsetEpsilon: number?): boolean
	scaleEpsilon = scaleEpsilon or 0.001
	offsetEpsilon = offsetEpsilon or 0.5

	local xScaleDifference = math.abs(current.X.Scale - target.X.Scale)
	local yScaleDifference = math.abs(current.Y.Scale - target.Y.Scale)
	local xOffsetDifference = math.abs(current.X.Offset - target.X.Offset)
	local yOffsetDifference = math.abs(current.Y.Offset - target.Y.Offset)

	return xScaleDifference < scaleEpsilon
		and yScaleDifference < scaleEpsilon
		and xOffsetDifference < offsetEpsilon
		and yOffsetDifference < offsetEpsilon
end

function animatorHelper.getRandomSmallY(guiObject: GuiObject): number
	return math.random(-guiObject.AbsoluteSize.Y * 0.05, guiObject.AbsoluteSize.Y * 0.05)
end

function animatorHelper.offsetToUdim2(offset: Vector2): UDim2
	return UDim2.fromOffset(offset.X, offset.Y)
end

return animatorHelper