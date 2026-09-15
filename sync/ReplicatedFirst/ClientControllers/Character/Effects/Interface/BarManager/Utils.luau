local barManagerUtils = {}

function barManagerUtils.isGuiObject(instance: Instance): boolean
	return instance:IsA("GuiObject")
end

function barManagerUtils.isImageGuiObject(instance: Instance): boolean
	return instance:IsA("ImageLabel") or instance:IsA("ImageButton")
end

function barManagerUtils.getFullAttribute(guiObject: GuiObject): boolean
	return guiObject:GetAttribute("Full") ~= false
end

function barManagerUtils.collectImageTargets(rootGuiObject: GuiObject): { GuiObject }
	local imageTargets = {}

	if barManagerUtils.isImageGuiObject(rootGuiObject) then
		table.insert(imageTargets, rootGuiObject)
	end

	for _, descendant in ipairs(rootGuiObject:GetDescendants()) do
		if barManagerUtils.isImageGuiObject(descendant) then
			table.insert(imageTargets, descendant)
		end
	end

	return imageTargets
end

return barManagerUtils
