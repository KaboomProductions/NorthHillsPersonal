local openShop = {}

function openShop.new(context, trackName)
	local animatorModule = context.animatorModule
	local uiCache = context.uiCache
	local shopFrame = context.ui.shopFrame
	local borders = context.ui.borders
	local mainPage = context.ui.mainPage

	local function play()
		animatorModule:cancel(trackName)

		shopFrame.Visible = true
		mainPage.Visible = true

		animatorModule:refreshOffsetBase("mainPagePosition")

		local mainPageBasePosition = uiCache:get(mainPage, "Position")
		local bordersBaseSize = uiCache:get(borders, "Size")

		local startOffset = Vector2.new(
			-mainPage.AbsoluteSize.X * 2,
			0
		)

		animatorModule:setSpring("mainPage", Vector2.zero, Vector2.zero, startOffset)
		animatorModule:impulseSpring("mainPage", Vector2.new(0, 0))

		mainPage.Position = mainPageBasePosition + UDim2.fromOffset(startOffset.X, startOffset.Y)

		local expandedBordersSize = bordersBaseSize + UDim2.fromOffset(0, shopFrame.AbsoluteSize.Y * 1.07)
		animatorModule:addSizeLerpTrack("bordersSize", borders, "Size", expandedBordersSize, bordersBaseSize, 10)
	end

	return play
end

return openShop
