--!strict

local itemVisualNames: { [string]: boolean } = {
	ItemIcon = true,
	ItemText = true,
	Count = true,
	DurabilityBar = true,
}

local liftedZIndexOffset = 1000

local itemVisuals = {}

local function offsetZIndex(visual: GuiObject, offset: number): ()
	visual.ZIndex += offset
	for _, descendant in visual:GetDescendants() do
		if descendant:IsA("GuiObject") then
			descendant.ZIndex += offset
		end
	end
end

function itemVisuals.lift(button: GuiButton, container: GuiObject): { GuiObject }
	local lifted: { GuiObject } = {}
	for _, child in button:GetChildren() do
		if itemVisualNames[child.Name] and child:IsA("GuiObject") then
			offsetZIndex(child, liftedZIndexOffset)
			child.Parent = container
			table.insert(lifted, child)
		end
	end
	return lifted
end

function itemVisuals.restore(button: GuiButton, lifted: { GuiObject }): ()
	for _, visual in lifted do
		offsetZIndex(visual, -liftedZIndexOffset)
		visual.Parent = button
	end
end

function itemVisuals.destroy(lifted: { GuiObject }): ()
	for _, visual in lifted do
		visual:Destroy()
	end
end

return itemVisuals
