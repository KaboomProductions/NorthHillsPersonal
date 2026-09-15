--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local itemUtils = require(replicatedStorage.SharedUtilities.ItemUtils)
local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)

local dragLayer = {}
dragLayer.__index = dragLayer

export type DragIntent = "CANCEL" | "DROP" | "INVALID" | "MOVE" | "MERGE" | "SWAP"

export type DragLayer = {
	frame: Frame?,
	image: ImageLabel?,
	label: TextLabel?,
	show: (self: DragLayer, descriptor: protocol.ItemDescriptor, point: Vector2) -> (),
	update: (self: DragLayer, point: Vector2) -> (),
	setIntent: (self: DragLayer, intent: DragIntent) -> (),
	hide: (self: DragLayer) -> (),
	destroy: (self: DragLayer) -> (),
}

function dragLayer.new(parent: Instance): DragLayer
	local frame = Instance.new("Frame")
	frame.Name = "InventoryDragLayer"
	frame.AnchorPoint = Vector2.new(0, 0)
	frame.Size = UDim2.fromOffset(180, 42)
	frame.BackgroundColor3 = Color3.fromRGB(145, 36, 30)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.ZIndex = 100
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = frame
	local image = Instance.new("ImageLabel")
	image.Name = "ItemImage"
	image.Position = UDim2.fromOffset(5, 5)
	image.Size = UDim2.fromOffset(32, 32)
	image.BackgroundTransparency = 1
	image.ScaleType = Enum.ScaleType.Fit
	image.Visible = false
	image.ZIndex = 101
	image.Parent = frame
	local label = Instance.new("TextLabel")
	label.Name = "ItemLabel"
	label.Position = UDim2.fromOffset(45, 0)
	label.Size = UDim2.new(1, -50, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 101
	label.Parent = frame
	local self: DragLayer = (
		setmetatable({ frame = frame, image = image, label = label }, dragLayer) :: unknown
	) :: DragLayer
	return self
end

function dragLayer:show(descriptor: protocol.ItemDescriptor, point: Vector2): ()
	local frame = self.frame
	local label = self.label
	if frame == nil or label == nil then
		return
	end
	local display = itemUtils.getDisplay(descriptor.itemType)
	local imageId = display and display.imageId
	local imageContent = if imageId and tostring(imageId) ~= "" then "rbxassetid://" .. tostring(imageId) else ""
	if self.image then
		self.image.Image = imageContent
		self.image.Visible = imageContent ~= ""
	end
	label.Text = string.format(
		"%s%s",
		descriptor.itemType,
		if descriptor.stackCount > 1 then " x" .. descriptor.stackCount else ""
	)
	frame.Position = UDim2.fromOffset(point.X + 12, point.Y + 12)
	frame.Visible = true
end

function dragLayer:update(point: Vector2): ()
	if self.frame then
		self.frame.Position = UDim2.fromOffset(point.X + 12, point.Y + 12)
	end
end

function dragLayer:setIntent(intent: DragIntent): ()
	if self.label then
		self.label.Text = intent
	end
end

function dragLayer:hide(): ()
	if self.frame then
		self.frame.Visible = false
	end
end

function dragLayer:destroy(): ()
	local frame = self.frame
	if frame then
		frame:Destroy()
	end
	table.clear(self)
end

return dragLayer
