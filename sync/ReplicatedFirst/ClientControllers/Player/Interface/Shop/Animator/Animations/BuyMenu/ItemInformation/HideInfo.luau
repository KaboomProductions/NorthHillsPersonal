local hideInfo = {}

function hideInfo.new(context, trackName)
	local animatorModule = context.animatorModule
	local informationFrame = context.ui.informationFrame

	local function play()
		animatorModule:cancel(trackName)
		if not informationFrame.Visible then return end

		local endOffset = Vector2.new(informationFrame.AbsoluteSize.X * 1.5, 0)

		animatorModule:setSpring("infoPanel", endOffset)
	end

	return play
end

return hideInfo
