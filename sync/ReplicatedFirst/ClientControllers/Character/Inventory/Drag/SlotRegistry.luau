--!strict

local replicatedStorage = game:GetService("ReplicatedStorage")

local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)

local slotRegistry = {}
slotRegistry.__index = slotRegistry

export type DragEntry = {
	zone: protocol.Zone,
	index: number,
	descriptor: protocol.ItemDescriptor?,
	locked: boolean,
	disabled: boolean,
}

type Slot = {
	zone: protocol.Zone,
	index: number,
	gui: GuiObject,
	getEntry: () -> DragEntry,
}

export type SlotRegistry = {
	slots: { Slot },
	containers: { GuiObject },
	dropZones: { GuiObject },
	register: (
		self: SlotRegistry,
		zone: protocol.Zone,
		index: number,
		gui: GuiObject,
		getEntry: () -> DragEntry
	) -> () -> (),
	registerContainer: (self: SlotRegistry, gui: GuiObject) -> () -> (),
	registerDropZone: (self: SlotRegistry, gui: GuiObject) -> () -> (),
	hitTest: (self: SlotRegistry, point: Vector2) -> DragEntry?,
	isInsideDropZone: (self: SlotRegistry, point: Vector2) -> boolean,
	isInsideUi: (self: SlotRegistry, point: Vector2) -> boolean,
	clear: (self: SlotRegistry) -> (),
}

local function inside(point: Vector2, gui: GuiObject): boolean
	local position = gui.AbsolutePosition
	local size = gui.AbsoluteSize
	return point.X >= position.X
		and point.Y >= position.Y
		and point.X <= position.X + size.X
		and point.Y <= position.Y + size.Y
end

local function isVisible(gui: GuiObject): boolean
	local current: Instance? = gui
	while current and current:IsA("GuiObject") do
		if not current.Visible then
			return false
		end
		current = current.Parent
	end
	return true
end

function slotRegistry.new(): SlotRegistry
	return (
		setmetatable({
			slots = {} :: { Slot },
			containers = {} :: { GuiObject },
			dropZones = {} :: { GuiObject },
		}, slotRegistry) :: unknown
	) :: SlotRegistry
end

function slotRegistry:register(zone: protocol.Zone, index: number, gui: GuiObject, getEntry: () -> DragEntry): () -> ()
	local entry: Slot = { zone = zone, index = index, gui = gui, getEntry = getEntry }
	table.insert(self.slots, entry)
	return function()
		for position, candidate in ipairs(self.slots) do
			if candidate == entry then
				table.remove(self.slots, position)
				break
			end
		end
	end
end

function slotRegistry:registerContainer(gui: GuiObject): () -> ()
	table.insert(self.containers, gui)
	return function()
		for position, candidate in ipairs(self.containers) do
			if candidate == gui then
				table.remove(self.containers, position)
				break
			end
		end
	end
end

function slotRegistry:registerDropZone(gui: GuiObject): () -> ()
	table.insert(self.dropZones, gui)
	return function()
		for position, candidate in ipairs(self.dropZones) do
			if candidate == gui then
				table.remove(self.dropZones, position)
				break
			end
		end
	end
end

function slotRegistry:hitTest(point: Vector2): DragEntry?
	for index = #self.slots, 1, -1 do
		local entry = self.slots[index]
		if entry.gui.Parent and isVisible(entry.gui) and inside(point, entry.gui) then
			return entry.getEntry()
		end
	end
	return nil
end

function slotRegistry:isInsideDropZone(point: Vector2): boolean
	for _, gui in ipairs(self.dropZones) do
		if gui.Parent and isVisible(gui) and inside(point, gui) then
			return true
		end
	end
	return false
end

function slotRegistry:isInsideUi(point: Vector2): boolean
	if self:isInsideDropZone(point) then
		return false
	end
	for _, gui in ipairs(self.containers) do
		if gui.Parent and isVisible(gui) and inside(point, gui) then
			return true
		end
	end
	return false
end

function slotRegistry:clear(): ()
	table.clear(self.slots)
	table.clear(self.containers)
	table.clear(self.dropZones)
end

return slotRegistry
