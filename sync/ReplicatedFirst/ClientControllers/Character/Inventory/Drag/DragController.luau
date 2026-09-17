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
local hoverCommitDelaySeconds = 0.12
local missingItemGraceSeconds = 0.1

type DragSource = () -> SlotRegistry.DragEntry?

type SlotAddress = {
	zone: protocol.Zone,
	index: number,
}

type DragSession = {
	itemId: string,
	startPosition: Vector2,
	moved: boolean,
}

type TrackedItem = {
	itemId: string,
	current: SlotAddress,
}

type MoveIntent = {
	itemId: string,
	zone: protocol.Zone,
	index: number,
}

type HoverKind = "current" | "move" | "swap" | "merge" | "invalid"

type PendingRelease = {
	kind: "merge" | "settle",
	itemId: string,
	target: SlotAddress,
	targetItemId: string?,
	generation: number,
}

export type DragController = {
	store: InventoryStore.Store?,
	requests: InventoryRequests.Requests?,
	registry: SlotRegistry.SlotRegistry?,
	layer: DragLayer.DragLayer?,
	session: DragSession?,
	tracked: TrackedItem?,
	activeDetector: UIDragDetector?,
	storeSyncThread: thread?,
	hoverTarget: SlotAddress?,
	hoverThread: thread?,
	desiredTarget: MoveIntent?,
	pendingRelease: PendingRelease?,
	isRequestInFlight: boolean,
	dragGeneration: number,
	hovered: SlotRegistry.DragEntry?,
	detectors: { [UIDragDetector]: DragSource },
	changedConnection: RBXScriptConnection?,
	_updateDetectors: (self: DragController) -> (),
	_onStoreChanged: (self: DragController) -> (),
	_syncTrackedItem: (self: DragController, tracked: TrackedItem, hasGraceExpired: boolean) -> (),
	_classifyHover: (self: DragController, itemId: string, target: SlotRegistry.DragEntry) -> HoverKind,
	_setHoverTarget: (self: DragController, address: SlotAddress) -> (),
	_clearHoverTarget: (self: DragController) -> (),
	_pumpRequests: (self: DragController) -> (),
	_sendMove: (self: DragController, intent: MoveIntent, target: SlotRegistry.DragEntry) -> (),
	_runRelease: (self: DragController, release: PendingRelease) -> (),
	_begin: (self: DragController, source: DragSource, sourceButton: GuiButton, inputPosition: unknown) -> (),
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

local function isSameAddress(first: SlotAddress?, second: SlotAddress?): boolean
	return first ~= nil and second ~= nil and first.zone == second.zone and first.index == second.index
end

local function dropDirection(): Vector3
	local camera = workspace.CurrentCamera
	return if camera then camera.CFrame.LookVector else Vector3.zAxis
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
			tracked = nil,
			activeDetector = nil,
			storeSyncThread = nil,
			hoverTarget = nil,
			hoverThread = nil,
			desiredTarget = nil,
			pendingRelease = nil,
			isRequestInFlight = false,
			dragGeneration = 0,
			detectors = {},
		}, dragController) :: unknown
	) :: DragController
	self.changedConnection = store.changed.Event:Connect(function()
		self:_onStoreChanged()
	end)
	return self
end

function dragController._onStoreChanged(self: DragController): ()
	self:_updateDetectors()

	local tracked = self.tracked
	if tracked == nil or self.storeSyncThread ~= nil then
		return
	end

	self.storeSyncThread = task.defer(function()
		self.storeSyncThread = nil
		if self.tracked == tracked then
			self:_syncTrackedItem(tracked, false)
		end
	end)
end

function dragController._syncTrackedItem(self: DragController, tracked: TrackedItem, hasGraceExpired: boolean): ()
	local store = self.store
	local registry = self.registry
	local layer = self.layer
	if store == nil or registry == nil or layer == nil or self.tracked ~= tracked then
		return
	end

	local foundZone, foundIndex = store:findItem(tracked.itemId)
	if foundZone == nil or foundIndex == nil then
		if hasGraceExpired then
			self.tracked = nil
			layer:finish()
			return
		end

		task.delay(missingItemGraceSeconds, function()
			self:_syncTrackedItem(tracked, true)
		end)
		return
	end
	local current: SlotAddress = { zone = foundZone :: protocol.Zone, index = foundIndex :: number }

	local previous = tracked.current
	if isSameAddress(current, previous) then
		return
	end
	tracked.current = current

	local currentSlot = registry:findSlot(current.zone, current.index)
	if currentSlot == nil or not currentSlot.gui:IsA("GuiButton") then
		layer:finish()
		return
	end

	local displacedButton: GuiButton? = nil
	local previousSlot = registry:findSlot(previous.zone, previous.index)
	if previousSlot and previousSlot.entry.descriptor ~= nil and previousSlot.gui:IsA("GuiButton") then
		displacedButton = previousSlot.gui
	end
	layer:relocate(currentSlot.gui, displacedButton)
end

function dragController._classifyHover(self: DragController, itemId: string, target: SlotRegistry.DragEntry): HoverKind
	local store = self.store
	if store == nil then
		return "invalid"
	end

	local foundZone: protocol.Zone?, foundIndex: number?, foundDescriptor: protocol.ItemDescriptor? =
		store:findItem(itemId)
	if foundZone == nil or foundIndex == nil or foundDescriptor == nil then
		return "invalid"
	end
	local canMove = canMoveToTarget(foundDescriptor, foundZone, target)
	local isCurrentSlot = target.zone == foundZone and target.index == foundIndex
	if isCurrentSlot then
		return "current"
	end
	if target.locked or target.disabled or not canMove then
		return "invalid"
	end

	local targetDescriptor = target.descriptor
	if targetDescriptor == nil then
		return "move"
	end
	return if targetDescriptor.itemType == foundDescriptor.itemType then "merge" else "swap"
end

function dragController._clearHoverTarget(self: DragController): ()
	local hoverThread = self.hoverThread
	self.hoverThread = nil
	self.hoverTarget = nil
	if hoverThread then
		task.cancel(hoverThread)
	end
end

function dragController._setHoverTarget(self: DragController, address: SlotAddress): ()
	if isSameAddress(self.hoverTarget, address) then
		return
	end

	self:_clearHoverTarget()
	self.hoverTarget = address

	local generation = self.dragGeneration
	self.hoverThread = task.delay(hoverCommitDelaySeconds, function()
		self.hoverThread = nil
		local session = self.session
		if session == nil or generation ~= self.dragGeneration then
			return
		end

		self.desiredTarget = { itemId = session.itemId, zone = address.zone, index = address.index }
		self:_pumpRequests()
	end)
end

function dragController._sendMove(self: DragController, intent: MoveIntent, target: SlotRegistry.DragEntry): ()
	local requests = self.requests
	if requests == nil then
		return
	end

	self.isRequestInFlight = true
	if target.descriptor then
		requests:swap(intent.itemId, intent.zone, intent.index)
	else
		requests:move(intent.itemId, intent.zone, intent.index)
	end
	self.isRequestInFlight = false

	if self.store == nil then
		return
	end
	self:_pumpRequests()
end

function dragController._runRelease(self: DragController, release: PendingRelease): ()
	local store = self.store
	local requests = self.requests
	local layer = self.layer
	if store == nil or requests == nil or layer == nil or release.generation ~= self.dragGeneration then
		return
	end

	if release.kind == "merge" and release.targetItemId then
		self.isRequestInFlight = true
		local response = requests:mergeStack(release.itemId, release.targetItemId)
		self.isRequestInFlight = false

		layer = self.layer
		if layer == nil or release.generation ~= self.dragGeneration then
			return
		end
		if response and response.ok then
			layer:finish()
		else
			layer:cancel()
		end
		return
	end

	local zone, index = store:findItem(release.itemId)
	if zone == release.target.zone and index == release.target.index then
		layer:finish()
	else
		layer:cancel()
	end
end

function dragController._pumpRequests(self: DragController): ()
	if self.isRequestInFlight then
		return
	end

	local registry = self.registry
	if registry == nil then
		return
	end

	local desired = self.desiredTarget
	if desired then
		self.desiredTarget = nil
		local slot = registry:findSlot(desired.zone, desired.index)
		if slot then
			local kind = self:_classifyHover(desired.itemId, slot.entry)
			if kind == "move" or kind == "swap" then
				self:_sendMove(desired, slot.entry)
				return
			end
		end
	end

	local release = self.pendingRelease
	if release then
		self.pendingRelease = nil
		self:_runRelease(release)
	end
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
		if detector == self.activeDetector and self.session ~= nil then
			continue
		end
		local entry = source()
		detector.Enabled = store:isEnabled()
			and entry ~= nil
			and entry.descriptor ~= nil
			and not entry.locked
			and not entry.disabled
	end
end

function dragController._begin(
	self: DragController,
	source: DragSource,
	_sourceButton: GuiButton,
	inputPosition: unknown
): ()
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
	self.dragGeneration += 1
	self:_clearHoverTarget()
	self.desiredTarget = nil
	self.pendingRelease = nil
	self.tracked = {
		itemId = entry.descriptor.itemId,
		current = { zone = entry.zone, index = entry.index },
	}

	self.session = {
		itemId = entry.descriptor.itemId,
		startPosition = point,
		moved = false,
	}
end

function dragController._continue(self: DragController, inputPosition: unknown): ()
	local session = self.session
	local tracked = self.tracked
	local registry = self.registry
	local layer = self.layer
	if session == nil or tracked == nil or registry == nil or layer == nil then
		return
	end

	local point = pointFromInput(inputPosition)
	if not session.moved then
		if (point - session.startPosition).Magnitude < dragThresholdPixels then
			return
		end

		local currentSlot = registry:findSlot(tracked.current.zone, tracked.current.index)
		if currentSlot == nil or not currentSlot.gui:IsA("GuiButton") then
			self.session = nil
			return
		end

		session.moved = true
		layer:show(currentSlot.gui)
	end

	local hit = registry:hitTestSlot(point)
	self.hovered = if hit then hit.entry else nil

	local previewTarget: GuiButton? = nil
	local kind: HoverKind = "invalid"
	if hit and hit.gui:IsA("GuiButton") then
		kind = self:_classifyHover(session.itemId, hit.entry)
		if kind ~= "invalid" then
			previewTarget = hit.gui
		end
	end

	if hit and (kind == "move" or kind == "swap") then
		self:_setHoverTarget({ zone = hit.entry.zone, index = hit.entry.index })
	else
		self:_clearHoverTarget()
	end

	layer:update(point, previewTarget, kind == "swap")
end

function dragController._end(self: DragController, inputPosition: unknown): boolean
	local session = self.session
	self.session = nil
	self.activeDetector = nil
	self.hovered = nil
	self:_clearHoverTarget()
	self:_updateDetectors()
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
	local layer = self.layer
	if store == nil or registry == nil or requests == nil or layer == nil or not store:isEnabled() then
		if layer then
			layer:cancel()
		end
		return false
	end

	local itemId = session.itemId
	local zone, index = store:findItem(itemId)
	if zone == nil or index == nil then
		layer:cancel()
		return false
	end

	if registry:isInsideDropZone(point) then
		layer:cancel()
		requests:drop(itemId, dropDirection())
		return false
	end

	local hit = registry:hitTestSlot(point)
	if hit and hit.gui:IsA("GuiButton") then
		local kind = self:_classifyHover(itemId, hit.entry)
		local target: SlotAddress = { zone = hit.entry.zone, index = hit.entry.index }
		local generation = self.dragGeneration
		if kind == "merge" and hit.entry.descriptor then
			layer:confirm(hit.gui, false)
			self.pendingRelease = {
				kind = "merge",
				itemId = itemId,
				target = target,
				targetItemId = hit.entry.descriptor.itemId,
				generation = generation,
			}
			self:_pumpRequests()
			return false
		end

		if kind == "move" or kind == "swap" then
			layer:confirm(hit.gui, kind == "swap")
			self.desiredTarget = { itemId = itemId, zone = target.zone, index = target.index }
			self.pendingRelease = { kind = "settle", itemId = itemId, target = target, generation = generation }
			self:_pumpRequests()
			return false
		end

		layer:cancel()
		return false
	end

	layer:cancel()
	if not registry:isInsideUi(point) then
		requests:drop(itemId, dropDirection())
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
			self.activeDetector = detector
			self:_begin(source, button, inputPosition)
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

function dragController.destroy(self: DragController): ()
	self:_clearHoverTarget()
	local storeSyncThread = self.storeSyncThread
	self.storeSyncThread = nil
	if storeSyncThread then
		task.cancel(storeSyncThread)
	end
	self.session = nil
	self.tracked = nil
	self.activeDetector = nil
	self.desiredTarget = nil
	self.pendingRelease = nil
	self.dragGeneration += 1
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
