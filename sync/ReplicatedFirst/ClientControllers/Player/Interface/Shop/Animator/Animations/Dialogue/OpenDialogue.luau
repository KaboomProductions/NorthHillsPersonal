local openDialogue = {}

function openDialogue.new(context, trackName)
	local animatorHelpers = context.animatorHelpers
	local animatorModule = context.animatorModule
	local uiCache = context.uiCache
	local dialogueFrame = context.ui.dialogueFrame

	local function play()
		if dialogueFrame.Visible then return end

		animatorModule:cancel(trackName)

		dialogueFrame.Visible = true

		animatorModule:refreshOffsetBase("dialoguePosition")

		local dialogueBasePosition = uiCache:get(dialogueFrame, "Position")

		local startOffset = Vector2.new(
			animatorHelpers.getRandomSmallY(dialogueFrame) * 0.5,
			dialogueFrame.AbsoluteSize.Y * .5
		)

		animatorModule:setSpring("dialogue", Vector2.zero, Vector2.zero, startOffset)
		animatorModule:impulseSpring("dialogue", Vector2.new(0, math.random(-400, -200)))

		dialogueFrame.Position = dialogueBasePosition + UDim2.fromOffset(startOffset.X, startOffset.Y)

		animatorModule:play(trackName, "openDialogue",
			function(_deltaTime: number)
				return animatorModule:isSpringSettled("dialogue")
			end,

			function()
				dialogueFrame.Position = dialogueBasePosition
			end
		)
	end

	return play
end

return openDialogue
