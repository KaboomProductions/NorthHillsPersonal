--!strict

local userInputService = game:GetService("UserInputService")
local guiService = game:GetService("GuiService")
local replicatedStorage = game:GetService("ReplicatedStorage")

local itemUtils = require(replicatedStorage.SharedUtilities.ItemUtils)
local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)
local InventoryStore = require(script.Parent.Parent.InventoryStore)
local InventoryRequests = require(script.Parent.Parent.Requests.InventoryRequests)
local DragLayer = require(script.Parent.DragLayer)
local SlotRegistry = require(script.Parent.SlotRegistry)

local dragController = {}
dragController.__index = dragController
local dragThresholdPixels = 8

type DragSource = () -> SlotRegistry.DragEntry?

type DragSession = {
	itemId: string,
	zone: protocol.Zone,
	index: number,
	descriptor: protocol.ItemDescriptor,
	startPosition: Vector2,
	moved: boolean,
}

export type DragController = {
	store: InventoryStore.Store?,
	requests: InventoryRequests.Requests?,
	registry: SlotRegistry.SlotRegistry?,
	layer: DragLayer.DragLayer?,
	session: DragSession?,
	hovered: SlotRegistry.DragEntry?,
	detectors: { [UIDragDetector]: DragSource },
	changedConnection: RBXScriptConnection?,
	_updateDetectors: (self: DragController) -> (),
	_begin: (self: DragController, source: DragSource, inputPosition: unknown) -> (),
	_continue: (self: DragController, inputPosition: unknown) -> (),
	_end: (self: DragController, inputPosition: unknown) -> boolean,
	attach: (self: DragController, button: GuiButton, source: DragSource, onActivated: (() -> ())?) -> () -> (),
	destroy: (self: DragController) -> (),
}

local function pointFromInput(inputPosition: unknown): Vector2
	local point = if typeof(inputPosition) == "Vector2" then inputPosition else userInputService:GetMouseLocation()
	local topLeftInset = select(1, guiService:GetGuiInset())
	return point - topLeftInset
end

local function canMoveToTarget(
	sourceDescriptor: protocol.ItemDescriptor,
	sourceZone: protocol.Zone,
	target: SlotRegistry.DragEntry
): boolean
	if not itemUtils.canMoveToZone(sourceDescriptor.itemType, target.zone) then
		return false
	end

	return target.descriptor == nil or itemUtils.canMoveToZone(target.descriptor.itemType, sourceZone)
end

function dragController.new(
	store: InventoryStore.Store,
	requests: InventoryRequests.Requests,
	registry: SlotRegistry.SlotRegistry,
	layer: DragLayer.DragLayer
): DragController
	local self: DragController = (
		setmetatable({
			store = store,
			requests = requests,
			registry = registry,
			layer = layer,
			session = nil,
			detectors = {},
		}, dragController) :: unknown
	) :: DragController
	self.changedConnection = store.changed.Event:Connect(function()
		self:_updateDetectors()
	end)
	return self
end

function dragController:_updateDetectors()
	local store = self.store
	if store == nil then
		for detector in self.detectors do
			detector.Enabled = false
		end
		return
	end
	for detector, source in self.detectors do
		local entry = source()
		detector.Enabled = store:isEnabled()
			and entry ~= nil
			and entry.descriptor ~= nil
			and not entry.locked
			and not entry.disabled
	end
end

function dragController:_begin(source: DragSource, inputPosition: unknown)
	local store = self.store
	local layer = self.layer
	if store == nil or layer == nil then
		return
	end
	local entry = source()
	if entry == nil or entry.locked or entry.disabled or not store:isEnabled() or entry.descriptor == nil then
		return
	end
	local point = pointFromInput(inputPosition)
	self.session = {
		itemId = entry.descriptor.itemId,
		zone = entry.zone,
		index = entry.index,
		descriptor = entry.descriptor,
		startPosition = point,
		moved = false,
	}
end

function dragController:_continue(inputPosition: unknown)
	local session = self.session
	local registry = self.registry
	local layer = self.layer
	if session == nil or registry == nil or layer == nil then
		return
	end
	local point = pointFromInput(inputPosition)
	if not session.moved then
		if (point - session.startPosition).Magnitude < dragThresholdPixels then
			return
		end
		session.moved = true
		layer:show(session.descriptor, point)
	end
	layer:update(point)
	self.hovered = registry:hitTest(point)
	local target = self.hovered
	if target == nil then
		layer:setIntent(if registry:isInsideUi(point) then "CANCEL" else "DROP")
	elseif target.locked or target.disabled then
		layer:setIntent("INVALID")
	else
		local store = self.store
		local sourceDescriptor: protocol.ItemDescriptor? = nil
		if store then
			local _, _, foundDescriptor = store:findItem(session.itemId)
			sourceDescriptor = foundDescriptor
		end
		if sourceDescriptor == nil or not canMoveToTarget(sourceDescriptor, session.zone, target) then
			layer:setIntent("INVALID")
		elseif target.descriptor == nil then
			layer:setIntent("MOVE")
		elseif target.descriptor.itemType == sourceDescriptor.itemType then
			layer:setIntent("MERGE")
		else
			layer:setIntent("SWAP")
		end
	end
end

function dragController:_end(inputPosition: unknown): boolean
	local session = self.session
	self.session = nil
	self.hovered = nil
	if self.layer then
		self.layer:hide()
	end
	if session == nil then
		return false
	end
	local point = pointFromInput(inputPosition)
	if not session.moved then
		return (point - session.startPosition).Magnitude < dragThresholdPixels
	end
	local store = self.store
	local registry = self.registry
	local requests = self.requests
	if store == nil or registry == nil or requests == nil or not store:isEnabled() then
		return false
	end
	local zone, index, descriptor = store:findItem(session.itemId)
	if zone == nil or index == nil or descriptor == nil then
		return false
	end
	local target = registry:hitTest(point)
	if registry:isInsideDropZone(point) then
		local direction = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.LookVector or Vector3.zAxis
		requests:drop(descriptor.itemId, direction)
		return false
	end
	if target then
		if target.locked or target.disabled then
			return false
		end
		if target.zone == zone and target.index == index then
			return false
		end
		if not canMoveToTarget(descriptor, zone, target) then
			return false
		end
		if target.descriptor and target.descriptor.itemType == descriptor.itemType then
			requests:mergeStack(descriptor.itemId, target.descriptor.itemId)
		elseif target.descriptor then
			requests:swap(descriptor.itemId, target.zone, target.index)
		else
			requests:move(descriptor.itemId, target.zone, target.index)
		end
		return false
	end
	if not registry:isInsideUi(point) then
		local direction = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.LookVector or Vector3.zAxis
		requests:drop(descriptor.itemId, direction)
	end
	return false
end

function dragController:attach(button: GuiButton, source: DragSource, onActivated: (() -> ())?): () -> ()
	local detector = Instance.new("UIDragDetector")
	detector.Name = "DragDetector"
	detector.DragStyle = Enum.UIDragDetectorDragStyle.TranslatePlane
	detector.ResponseStyle = Enum.UIDragDetectorResponseStyle.CustomOffset
	detector.Parent = button
	self.detectors[detector] = source
	self:_updateDetectors()
	local connections: { [string]: RBXScriptConnection } = {
		start = detector.DragStart:Connect(function(inputPosition)
			self:_begin(source, inputPosition)
		end),
		continue = detector.DragContinue:Connect(function(inputPosition)
			self:_continue(inputPosition)
		end),
		finish = detector.DragEnd:Connect(function(inputPosition)
			local wasClick = self:_end(inputPosition)
			if wasClick and onActivated then
				onActivated()
			end
		end),
		activate = button.Activated:Connect(function()
			if not detector.Enabled and onActivated then
				onActivated()
			end
		end),
	}
	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
		self.detectors[detector] = nil
		detector:Destroy()
	end
end

function dragController:destroy(): ()
	self.session = nil
	self.hovered = nil
	if self.changedConnection then
		self.changedConnection:Disconnect()
	end
	table.clear(self.detectors)
	self.store = nil
	self.requests = nil
	self.registry = nil
	self.layer = nil
end

return dragController
