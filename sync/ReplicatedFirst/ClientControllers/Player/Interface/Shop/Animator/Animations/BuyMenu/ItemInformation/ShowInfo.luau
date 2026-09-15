local showInfo = {}

function showInfo.new(context, trackName)
	local animatorModule = context.animatorModule
	local informationFrame = context.ui.informationFrame
	
	local startOffset = Vector2.new(informationFrame.AbsoluteSize.X * 1.5, 0)
	
	local function preload()
		animatorModule:setSpring("infoPanel", startOffset, Vector2.zero, startOffset)
	end

	local function play()
		animatorModule:cancel(trackName)

		informationFrame.Visible = true

		animatorModule:refreshOffsetBase("infoPanelPosition")

		animatorModule:setSpring("infoPanel", Vector2.zero)
		animatorModule:impulseSpring("infoPanel", Vector2.new(math.random(-300, -150), 0))
	end

	return play, preload
end

return showInfo
