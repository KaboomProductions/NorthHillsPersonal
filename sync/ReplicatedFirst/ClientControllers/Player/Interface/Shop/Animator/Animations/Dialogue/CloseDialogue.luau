local closeDialogue = {}

function closeDialogue.new(context, trackName)
	local animatorModule = context.animatorModule
	local uiCache = context.uiCache
	local dialogueFrame = context.ui.dialogueFrame

	local function play()
		animatorModule:cancel(trackName)
		if not dialogueFrame.Visible then return end

		local dialogueBasePosition = uiCache:get(dialogueFrame, "Position")
		local endOffset = Vector2.new(0, dialogueFrame.AbsoluteSize.Y * .5)

		animatorModule:setSpring("dialogue", endOffset)

		animatorModule:play(trackName, "closeDialogue",
			function(_deltaTime: number)
				return animatorModule:isSpringSettled("dialogue")
			end,

			function()
				dialogueFrame.Position = dialogueBasePosition
				dialogueFrame.Visible = false
			end
		)
	end

	return play
end

return closeDialogue
