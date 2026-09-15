local tweenService = game:GetService("TweenService")

local guiUtilities = {}

function guiUtilities.isPointerInput(inputObject: InputObject): boolean
	local userInputType = inputObject.UserInputType

	return userInputType == Enum.UserInputType.MouseButton1 or userInputType == Enum.UserInputType.Touch
end

guiUtilities.uiClassProperties = {
	TextLabel = { "TextTransparency", "TextStrokeTransparency" },
	TextButton = { "TextTransparency", "TextStrokeTransparency" },
	TextBox = { "TextTransparency", "TextStrokeTransparency" },
	ImageLabel = { "ImageTransparency" },
	ImageButton = { "ImageTransparency" },
	ViewportFrame = { "ImageTransparency" },
	ScrollingFrame = { "ScrollBarImageTransparency" },
	UIStroke = { "Transparency" },
}

function guiUtilities.changeGuiState(info: {
	frame: Frame,
	state: boolean,
	tweenInfo: TweenInfo?,
	killOnCompleted: boolean?,
})
	local descendants = info.frame:GetDescendants()
	local tweenList = {}

	local progress = Instance.new("NumberValue")
	local progressTween = tweenService:Create(progress, info.tweenInfo or TweenInfo.new(), {
		Value = 1,
	})

	if info.frame:IsA("GuiObject") then
		table.insert(descendants, info.frame)
	end

	for _, object in pairs(descendants) do
		local className = object.ClassName
		local properties = guiUtilities.uiClassProperties[className]
		local toTween = {}

		if not properties and object:IsA("Frame") then
			properties = {}
		end

		if not properties then
			continue
		else
			if not object:IsA("Frame") then
				properties = table.clone(properties)
			end

			if not object:IsA("UIComponent") then
				table.insert(properties, "BackgroundTransparency")
			end
		end

		for _, property in pairs(properties) do
			local propertyId = "Original" .. property

			if not object:GetAttribute(propertyId) then
				object:SetAttribute(propertyId, object[property])
			end

			toTween[property] = info.state and (object:GetAttribute(propertyId) or 0) or 1
		end

		if info.tweenInfo then
			table.insert(tweenList, tweenService:Create(object, info.tweenInfo, toTween))
		else
			for property, value in pairs(toTween) do
				object[property] = value
			end
		end
	end

	for _, toPlay in pairs(tweenList) do
		toPlay:Play()
	end

	progressTween:Play()

	task.spawn(function()
		if info.killOnCompleted then
			progressTween.Completed:Wait()

			if info.frame then
				info.frame:Destroy()
			end
		end
	end)

	return progressTween
end

return guiUtilities
