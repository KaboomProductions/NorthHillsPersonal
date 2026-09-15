--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local itemUtils = require(replicatedStorage.SharedUtilities.ItemUtils)
local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)
local vide = require(replicatedStorage.ExternalLibraries.vide)

local constants = require(script.Parent.Parent.Parent.Constants)
local InventoryRequests = require(script.Parent.Parent.Parent.Requests.InventoryRequests)
local InventoryStore = require(script.Parent.Parent.Parent.InventoryStore)
local SlotRegistry = require(script.Parent.Parent.Parent.Drag.SlotRegistry)
local ThrowFlow = require(script.Parent.Parent.Parent.Requests.ThrowFlow)
local create = vide.create

export type Props = {
	state: InventoryStore.StateSource,
	selected: InventoryStore.Source<SlotRegistry.DragEntry?>,
	onEquip: (index: number) -> (),
	requests: InventoryRequests.Requests,
	throwFlow: ThrowFlow.ThrowFlow,
}

local function findEmpty(state: InventoryStore.ReadOnlyState): (protocol.Zone?, number?)
	for index = 1, state.storageCapacity do
		if state.storage[tostring(index)] == nil then
			return protocol.Zones.storage, index
		end
	end
	for index = 1, protocol.Limits.hotbarCapacity do
		if state.hotbar[tostring(index)] == nil then
			return protocol.Zones.hotbar, index
		end
	end
	return nil, nil
end

return function(props: Props)
	local splitCount: InventoryStore.Source<string> = vide.source("1") :: InventoryStore.Source<string>
	local selectedDescriptor = function(): protocol.ItemDescriptor?
		local selected = props.selected()
		if selected == nil or selected.descriptor == nil then
			return nil
		end
		local itemId = selected.descriptor.itemId
		local state = props.state()
		for _, zone in ipairs({ protocol.Zones.hotbar, protocol.Zones.storage }) do
			local map = if zone == protocol.Zones.hotbar then state.hotbar else state.storage
			local typedMap = map :: { [string]: protocol.ItemDescriptor }
			for _, descriptor in typedMap do
				if descriptor.itemId == itemId then
					return descriptor
				end
			end
		end
		return nil
	end
	local selectedItemType = function(): string?
		local descriptor = selectedDescriptor()
		return descriptor and descriptor.itemType or nil
	end
	local function actionButton(label, order, callback, visible)
		return create("TextButton")({
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundColor3 = Color3.fromRGB(42, 44, 48),
			BorderSizePixel = 0,
			Font = Enum.Font.GothamMedium,
			Text = label,
			TextColor3 = constants.textColor,
			TextSize = 13,
			Visible = if visible == nil then true else visible,
			MouseButton1Click = callback,
		})
	end
	local splitBox
	splitBox = create("TextBox")({
		LayoutOrder = 6,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = Color3.fromRGB(31, 33, 36),
		BorderSizePixel = 0,
		Font = Enum.Font.Gotham,
		Text = "1",
		PlaceholderText = "Split count",
		TextColor3 = constants.textColor,
		TextSize = 13,
		FocusLost = function()
			splitCount(splitBox.Text)
		end,
	})

	return create("Frame")({
		Name = "ContextMenu",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.97, 0.5),
		Size = UDim2.fromOffset(210, 300),
		BackgroundColor3 = constants.panelColor,
		BorderSizePixel = 0,
		Visible = function()
			return props.selected() ~= nil and selectedDescriptor() ~= nil and props.state().enabled
		end,
		create("UICorner")({ CornerRadius = UDim.new(0, 5) }),
		create("UIListLayout")({ Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
		create("TextLabel")({
			LayoutOrder = 0,
			Size = UDim2.new(1, 0, 0, 52),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = function()
				local itemType = selectedItemType()
				local display = if itemType then itemUtils.getDisplay(itemType) else nil
				return display and display.displayName or "Item"
			end,
			TextColor3 = constants.textColor,
			TextSize = 16,
			TextWrapped = true,
		}),
		actionButton("Equip", 1, function()
			local selected = props.selected()
			if selected and selected.zone == protocol.Zones.hotbar then
				props.onEquip(selected.index)
				props.selected(nil)
			end
		end, function()
			local selected = props.selected()
			return selected ~= nil and selected.zone == protocol.Zones.hotbar and selected.descriptor ~= nil
		end),
		actionButton("Drop", 2, function()
			local descriptor = selectedDescriptor()
			if descriptor then
				local direction = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.LookVector or Vector3.zAxis
				props.requests:drop(descriptor.itemId, direction)
				props.selected(nil)
			end
		end),
		actionButton("Throw", 3, function()
			local descriptor = selectedDescriptor()
			if descriptor then
				props.throwFlow:throw(descriptor.itemId)
				props.selected(nil)
			end
		end, function()
			local selected = props.selected()
			local state = props.state()
			local itemType = selectedItemType()
			return itemType ~= nil
				and itemUtils.getThrowableConfig(itemType) ~= nil
				and selected ~= nil
				and selected.zone == protocol.Zones.hotbar
				and selected.index == state.currentSlot
		end),
		actionButton("Upgrade", 4, function()
			local descriptor = selectedDescriptor()
			local upgrades = if descriptor then itemUtils.getUpgrades(descriptor.itemType) else nil
			local candidate = upgrades and upgrades[1]
			if descriptor and candidate then
				props.requests:upgrade(descriptor.itemId, candidate.id)
				props.selected(nil)
			end
		end, function()
			local itemType = selectedItemType()
			local upgrades = if itemType then itemUtils.getUpgrades(itemType) else nil
			return upgrades ~= nil and #upgrades > 0
		end),
		actionButton("Use Backpack", 5, function()
			local descriptor = selectedDescriptor()
			if descriptor then
				props.requests:useCapacityUpgrade(descriptor.itemId)
				props.selected(nil)
			end
		end, function()
			local itemType = selectedItemType()
			return itemType ~= nil and itemUtils.getCapacityIncrease(itemType) ~= nil
		end),
		splitBox,
		actionButton("Split Stack", 7, function()
			local descriptor = selectedDescriptor()
			local count = tonumber(splitCount())
			local zone, index = findEmpty(props.state())
			if descriptor == nil or count == nil or zone == nil or index == nil then
				return
			end
			local targetZone: protocol.Zone
			if zone == "hotbar" then
				targetZone = "hotbar"
			else
				targetZone = "storage"
			end
			local targetIndex: number = index
			props.requests:splitStack(descriptor.itemId, math.floor(count), targetZone, targetIndex)
			props.selected(nil)
		end, function()
			local descriptor = selectedDescriptor()
			return descriptor ~= nil and descriptor.stackCount > 1
		end),
		actionButton("Close", 8, function()
			props.selected(nil)
		end),
	})
end
