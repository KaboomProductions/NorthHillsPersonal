local closeBuy = {}

function closeBuy.new(context, trackName)
	local animatorModule = context.animatorModule
	local uiCache = context.uiCache
	local mainPage = context.ui.mainPage

	local function play()
		animatorModule:cancel(trackName)

		mainPage.Visible = true

		local mainPageBasePosition = uiCache:get(mainPage, "Position")

		local startMainPageOffset = Vector2.new(0, mainPage.AbsoluteSize.Y * 2)
		local endItemTabsOffset = Vector2.new(0, -mainPage.AbsoluteSize.Y * 2)

		animatorModule:setSpring("mainPage", Vector2.zero)
		animatorModule:setSpring("itemTabs", endItemTabsOffset)

		mainPage.Position = mainPageBasePosition + UDim2.fromOffset(startMainPageOffset.X, startMainPageOffset.Y)
	end

	return play
end

return closeBuy
