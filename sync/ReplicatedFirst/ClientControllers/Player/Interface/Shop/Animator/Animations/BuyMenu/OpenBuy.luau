local openBuy = {}

function openBuy.new(context, trackName)
	local animatorModule = context.animatorModule
	local buyPage = context.ui.buyPage
	local mainPage = context.ui.mainPage
	
	local endMainPageOffset = Vector2.new(0, mainPage.AbsoluteSize.Y * 2)
	local startItemTabsOffset = Vector2.new(0, -mainPage.AbsoluteSize.Y * 2)
	
	local function preload()
		animatorModule:setSpring("itemTabs", startItemTabsOffset, Vector2.zero, startItemTabsOffset)
	end

	local function play()
		animatorModule:cancel(trackName)

		buyPage.Visible = true

		animatorModule:setSpring("mainPage", endMainPageOffset)
		animatorModule:setSpring("itemTabs", Vector2.zero)
	end

	return play, preload
end

return openBuy
