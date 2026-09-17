--!strict

local protocol = {}

export type Zone = "hotbar" | "storage"
export type ActionName =
	| "drop"
	| "equip"
	| "mergeStack"
	| "move"
	| "releaseThrow"
	| "splitStack"
	| "swap"
	| "throw"
	| "unequip"
	| "upgrade"
	| "useCapacityUpgrade"
export type Primitive = boolean | number | string

export type ItemRecord = {
	itemId: string?,
	itemType: string,
	stackCount: number,
	attributes: { [string]: Primitive },
}

export type ItemDescriptor = {
	itemId: string,
	itemType: string,
	stackCount: number,
	attributes: { [string]: Primitive },
}

export type InventoryState = {
	enabled: boolean,
	disabledReason: string?,
	storageCapacity: number,
	currentSlot: number?,
	equipIntentSequence: number,
	hotbar: { [string]: ItemDescriptor },
	storage: { [string]: ItemDescriptor },
	materials: { [string]: number },
}

export type DropPayload = {
	action: "drop",
	itemId: string,
	dropDirection: Vector3?,
}

export type EquipPayload = {
	action: "equip",
	slotNumber: number,
	intentSequence: number,
}

export type MergeStackPayload = {
	action: "mergeStack",
	sourceItemId: string,
	targetItemId: string,
}

export type MovePayload = {
	action: "move",
	itemId: string,
	toZone: Zone,
	toIndex: number,
}

export type SwapPayload = {
	action: "swap",
	itemId: string,
	toZone: Zone,
	toIndex: number,
}

export type ReleaseThrowPayload = {
	action: "releaseThrow",
	throwId: string,
}

export type SplitStackPayload = {
	action: "splitStack",
	itemId: string,
	count: number,
	toZone: Zone,
	toIndex: number,
}

export type ThrowPayload = {
	action: "throw",
	itemId: string,
	aimDirection: Vector3,
}

export type UnequipPayload = {
	action: "unequip",
	intentSequence: number,
}

export type UpgradePayload = {
	action: "upgrade",
	itemId: string,
	upgradeId: string,
}

export type CapacityUpgradePayload = {
	action: "useCapacityUpgrade",
	itemId: string,
}

export type ActionPayloads = {
	drop: DropPayload,
	equip: EquipPayload,
	mergeStack: MergeStackPayload,
	move: MovePayload,
	releaseThrow: ReleaseThrowPayload,
	splitStack: SplitStackPayload,
	swap: SwapPayload,
	throw: ThrowPayload,
	unequip: UnequipPayload,
	upgrade: UpgradePayload,
	useCapacityUpgrade: CapacityUpgradePayload,
}

export type ActionPayload =
	| DropPayload
	| EquipPayload
	| MergeStackPayload
	| MovePayload
	| ReleaseThrowPayload
	| SplitStackPayload
	| SwapPayload
	| ThrowPayload
	| UnequipPayload
	| UpgradePayload
	| CapacityUpgradePayload

export type ResponseCode =
	| "busy"
	| "capacityMax"
	| "disabled"
	| "internalError"
	| "invalidPayload"
	| "invalidSlot"
	| "invalidStackCount"
	| "inventoryFull"
	| "missingMaterials"
	| "holstering"
	| "notEquippable"
	| "notOwned"
	| "notReady"
	| "notThrowable"
	| "notUpgradeable"
	| "occupied"
	| "ok"
	| "pending"
	| "queueFull"
	| "rateLimited"
	| "staleThrow"

export type InventoryResponse = {
	ok: boolean,
	code: ResponseCode,
	data: unknown?,
}

local Zones = table.freeze({
	hotbar = "hotbar" :: Zone,
	storage = "storage" :: Zone,
})

local Actions = table.freeze({
	drop = "drop" :: "drop",
	equip = "equip" :: "equip",
	mergeStack = "mergeStack" :: "mergeStack",
	move = "move" :: "move",
	releaseThrow = "releaseThrow" :: "releaseThrow",
	splitStack = "splitStack" :: "splitStack",
	swap = "swap" :: "swap",
	throw = "throw" :: "throw",
	unequip = "unequip" :: "unequip",
	upgrade = "upgrade" :: "upgrade",
	useCapacityUpgrade = "useCapacityUpgrade" :: "useCapacityUpgrade",
})

local ResponseCodes = table.freeze({
	busy = "busy" :: "busy",
	capacityMax = "capacityMax" :: "capacityMax",
	disabled = "disabled" :: "disabled",
	internalError = "internalError" :: "internalError",
	invalidPayload = "invalidPayload" :: "invalidPayload",
	invalidSlot = "invalidSlot" :: "invalidSlot",
	invalidStackCount = "invalidStackCount" :: "invalidStackCount",
	inventoryFull = "inventoryFull" :: "inventoryFull",
	missingMaterials = "missingMaterials" :: "missingMaterials",
	holstering = "holstering" :: "holstering",
	notEquippable = "notEquippable" :: "notEquippable",
	notOwned = "notOwned" :: "notOwned",
	notReady = "notReady" :: "notReady",
	notThrowable = "notThrowable" :: "notThrowable",
	notUpgradeable = "notUpgradeable" :: "notUpgradeable",
	occupied = "occupied" :: "occupied",
	ok = "ok" :: "ok",
	pending = "pending" :: "pending",
	queueFull = "queueFull" :: "queueFull",
	rateLimited = "rateLimited" :: "rateLimited",
	staleThrow = "staleThrow" :: "staleThrow",
})

protocol.Zones = Zones
protocol.Actions = Actions
protocol.ResponseCodes = ResponseCodes

protocol.Limits = table.freeze({
	hotbarCapacity = 6,
	storageCapacityDefault = 12,
	storageCapacityIncrease = 5,
	storageCapacityMaximum = 12,
	maximumIdentifierLength = 128,
	maximumQueueDepth = 32,
	remoteWaitSeconds = 10,
	intentSequenceMaxFutureSeconds = 60,
})

local function isFiniteNumber(value: unknown): boolean
	return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function isInteger(value: unknown): boolean
	return isFiniteNumber(value) and (value :: number) % 1 == 0
end

local function isIdentifier(value: unknown): boolean
	return typeof(value) == "string" and #value > 0 and #value <= protocol.Limits.maximumIdentifierLength
end

local function isZone(value: unknown): boolean
	return value == Zones.hotbar or value == Zones.storage
end

local function isSlot(zone: unknown, index: unknown): boolean
	if not isZone(zone) or not isInteger(index) then
		return false
	end

	if zone == Zones.hotbar then
		return (index :: number) >= 1 and (index :: number) <= protocol.Limits.hotbarCapacity
	end

	return (index :: number) >= 1 and (index :: number) <= protocol.Limits.storageCapacityMaximum
end

local function isFiniteVector3(value: unknown): boolean
	return typeof(value) == "Vector3"
		and isFiniteNumber((value :: Vector3).X)
		and isFiniteNumber((value :: Vector3).Y)
		and isFiniteNumber((value :: Vector3).Z)
		and (value :: Vector3).Magnitude > 0
end

local function asTable(value: unknown): { [string]: unknown }?
	return if typeof(value) == "table" then value :: { [string]: unknown } else nil
end

local function validateDrop(payload: { [string]: unknown }): boolean
	return isIdentifier(payload.itemId) and (payload.dropDirection == nil or isFiniteVector3(payload.dropDirection))
end

local function validateEquip(payload: { [string]: unknown }): boolean
	return isInteger(payload.slotNumber)
		and (payload.slotNumber :: number) >= 1
		and (payload.slotNumber :: number) <= protocol.Limits.hotbarCapacity
		and isInteger(payload.intentSequence)
		and (payload.intentSequence :: number) >= 0
end

local function validateMergeStack(payload: { [string]: unknown }): boolean
	return isIdentifier(payload.sourceItemId)
		and isIdentifier(payload.targetItemId)
		and payload.sourceItemId ~= payload.targetItemId
end

local function validateMove(payload: { [string]: unknown }): boolean
	return isIdentifier(payload.itemId) and isSlot(payload.toZone, payload.toIndex)
end

local function validateReleaseThrow(payload: { [string]: unknown }): boolean
	return isIdentifier(payload.throwId)
end

local function validateSplitStack(payload: { [string]: unknown }): boolean
	return isIdentifier(payload.itemId)
		and isInteger(payload.count)
		and (payload.count :: number) >= 1
		and isSlot(payload.toZone, payload.toIndex)
end

local function validateThrow(payload: { [string]: unknown }): boolean
	return isIdentifier(payload.itemId) and isFiniteVector3(payload.aimDirection)
end

local function validateUpgrade(payload: { [string]: unknown }): boolean
	return isIdentifier(payload.itemId) and isIdentifier(payload.upgradeId)
end

local function validateCapacityUpgrade(payload: { [string]: unknown }): boolean
	return isIdentifier(payload.itemId)
end

local function validateUnequip(payload: { [string]: unknown }): boolean
	for key in pairs(payload) do
		if key ~= "action" and key ~= "intentSequence" then
			return false
		end
	end
	return isInteger(payload.intentSequence) and (payload.intentSequence :: number) >= 0
end

function protocol.isFiniteNumber(value: unknown): boolean
	return isFiniteNumber(value)
end

function protocol.isFiniteVector3(value: unknown): boolean
	return isFiniteVector3(value)
end

function protocol.isZone(value: unknown): boolean
	return isZone(value)
end

function protocol.isSlot(zone: unknown, index: unknown): boolean
	return isSlot(zone, index)
end

function protocol.validateRequest(payload: unknown): (ActionPayload?, ResponseCode?)
	local request = asTable(payload)
	if request == nil or not isIdentifier(request.action) then
		return nil, ResponseCodes.invalidPayload
	end

	local action = request.action
	if action == Actions.drop and validateDrop(request) then
		return {
			action = Actions.drop,
			itemId = request.itemId :: string,
			dropDirection = request.dropDirection :: Vector3?,
		},
			nil
	elseif action == Actions.equip and validateEquip(request) then
		return {
			action = Actions.equip,
			slotNumber = request.slotNumber :: number,
			intentSequence = request.intentSequence :: number,
		},
			nil
	elseif action == Actions.mergeStack and validateMergeStack(request) then
		return {
			action = Actions.mergeStack,
			sourceItemId = request.sourceItemId :: string,
			targetItemId = request.targetItemId :: string,
		},
			nil
	elseif action == Actions.move and validateMove(request) then
		return {
			action = Actions.move,
			itemId = request.itemId :: string,
			toZone = request.toZone :: Zone,
			toIndex = request.toIndex :: number,
		},
			nil
	elseif action == Actions.swap and validateMove(request) then
		return {
			action = Actions.swap,
			itemId = request.itemId :: string,
			toZone = request.toZone :: Zone,
			toIndex = request.toIndex :: number,
		},
			nil
	elseif action == Actions.releaseThrow and validateReleaseThrow(request) then
		return { action = Actions.releaseThrow, throwId = request.throwId :: string }, nil
	elseif action == Actions.splitStack and validateSplitStack(request) then
		return {
			action = Actions.splitStack,
			itemId = request.itemId :: string,
			count = request.count :: number,
			toZone = request.toZone :: Zone,
			toIndex = request.toIndex :: number,
		},
			nil
	elseif action == Actions.throw and validateThrow(request) then
		return {
			action = Actions.throw,
			itemId = request.itemId :: string,
			aimDirection = request.aimDirection :: Vector3,
		},
			nil
	elseif action == Actions.unequip and validateUnequip(request) then
		return { action = Actions.unequip, intentSequence = request.intentSequence :: number }, nil
	elseif action == Actions.upgrade and validateUpgrade(request) then
		return {
			action = Actions.upgrade,
			itemId = request.itemId :: string,
			upgradeId = request.upgradeId :: string,
		},
			nil
	elseif action == Actions.useCapacityUpgrade and validateCapacityUpgrade(request) then
		return { action = Actions.useCapacityUpgrade, itemId = request.itemId :: string }, nil
	end

	return nil, ResponseCodes.invalidPayload
end

function protocol.success(data: unknown?): InventoryResponse
	return {
		ok = true,
		code = ResponseCodes.ok,
		data = data,
	}
end

function protocol.failure(code: ResponseCode, data: unknown?): InventoryResponse
	return {
		ok = false,
		code = code,
		data = data,
	}
end

return table.freeze(protocol)
