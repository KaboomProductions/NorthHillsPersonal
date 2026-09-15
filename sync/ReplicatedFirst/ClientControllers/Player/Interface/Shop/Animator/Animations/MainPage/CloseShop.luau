local closeShop = {}

function closeShop.new(context, trackName)
	local animatorHelpers = context.animatorHelpers
	local animatorModule = context.animatorModule
	local uiCache = context.uiCache
	local shopFrame = context.ui.shopFrame
	local borders = context.ui.borders
	local mainPage = context.ui.mainPage

	local function play()
		animatorModule:cancel(trackName)
		if not shopFrame.Visible then return end

		local mainPageBasePosition = uiCache:get(mainPage, "Position")
		local bordersBaseSize = uiCache:get(borders, "Size")

		local endOffset = Vector2.new(
			-mainPage.AbsoluteSize.X * 2,
			animatorHelpers.getRandomSmallY(mainPage)
		)

		animatorModule:setSpring("mainPage", endOffset)

		local targetBordersSize = bordersBaseSize + UDim2.fromOffset(0, shopFrame.AbsoluteSize.Y * 1.07)
		animatorModule:addSizeLerpTrack("bordersSize", borders, "Size", borders.Size, targetBordersSize, 1)
		
		animatorModule:play(trackName, "closeShop",
			function(_deltaTime: number)
				local mainPageSpring = animatorModule:getSpring("mainPage")
				local mainPageSettled = animatorHelpers.isSpringSettled(mainPageSpring, endOffset)

				local bordersTrack = animatorModule.tracks["bordersSize"]
				local bordersSettled = bordersTrack and animatorHelpers.isUdim2Settled(bordersTrack.currentValue, targetBordersSize) or true

				return mainPageSettled and bordersSettled
			end,

			function()
				mainPage.Position = mainPageBasePosition
				borders.Size = bordersBaseSize
				shopFrame.Visible = false
				animatorModule:removeTrack("bordersSize")
			end
		)
	end

	return play
end

return closeShop
