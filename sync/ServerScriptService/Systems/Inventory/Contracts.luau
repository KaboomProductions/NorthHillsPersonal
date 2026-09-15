--!strict

local protocol = require(game:GetService("ReplicatedStorage").SharedUtilities.InventoryProtocol)
local configTypes = require(game:GetService("ReplicatedStorage").SharedAssets.Dictionaries.ItemConfigTypes)

-- Metatable-backed instances need an explicit boundary because __index methods are not merged into literals.
export type PersistentAttributes = configTypes.PersistentAttributes
export type StackConfig = configTypes.StackConfig
export type ThrowableConfig = configTypes.ThrowableConfig
export type RigJoint = configTypes.RigJoint
export type UpgradeMaterial = configTypes.UpgradeCost
export type Upgrade = configTypes.Upgrade
export type BaseConfig = configTypes.BaseConfig

export type CreateRecord = {
	itemId: string?,
	stackCount: number?,
	attributes: PersistentAttributes?,
}

export type SerializedInventory = {
	schemaVersion: number,
	hotbar: { [string]: protocol.ItemRecord },
	storage: { [string]: protocol.ItemRecord },
	storageCapacity: number,
	materials: { [string]: number },
}

export type IndexEntry = {
	item: Model,
	slot: ObjectValue,
	zone: protocol.Zone,
	index: number,
}

export type ReplicaHandle = {
	Destroy: (ReplicaHandle) -> (),
	IsActive: (ReplicaHandle) -> boolean,
	Set: (ReplicaHandle, { string }, unknown) -> (),
	Subscribe: (ReplicaHandle, Player) -> (),
}

export type Replica = {
	player: Player,
	replica: ReplicaHandle?,
	readyConnection: RBXScriptConnection?,
	sync: (Replica, State) -> (),
	setSlot: (Replica, protocol.Zone, number, protocol.ItemDescriptor?) -> (),
	setCapacity: (Replica, number) -> (),
	setCurrentSlot: (Replica, number?) -> (),
	setEquipIntentSequence: (Replica, number) -> (),
	setMaterial: (Replica, string, number) -> (),
	setEnabled: (Replica, boolean, string?) -> (),
	destroy: (Replica) -> (),
}

export type TransactionValue = boolean | protocol.InventoryResponse | {
	config: BaseConfig,
	state: State,
	slot: ObjectValue,
	item: Model,
} | {
	ok: boolean,
	code: protocol.ResponseCode,
	granted: number,
	remaining: number,
	items: { protocol.ItemDescriptor },
}

export type TransactionCallback = () -> TransactionValue?

export type TransactionResult = {
	n: number,
	[number]: unknown,
}

export type TransactionEntry = {
	callback: TransactionCallback,
	done: BindableEvent,
	result: TransactionResult?,
}

export type TransactionQueue = {
	queue: { TransactionEntry },
	running: boolean,
	inCriticalSection: boolean,
	removing: boolean,
	_drain: (TransactionQueue, Player?) -> (),
	withLock: (TransactionQueue, Player, TransactionCallback) -> ...unknown,
	destroy: (TransactionQueue) -> (),
}

export type EquipTransition = {
	desiredSlot: number?,
	lastIntentSequence: number,
	holsterWakeSignal: BindableEvent,
	holsterWaitVersion: number,
	holsteringSlot: number?,
	transitionVersion: number,
	running: boolean,
	forceCleanup: boolean,
	destroyed: boolean,
	setDesiredSlot: (EquipTransition, number?, number?) -> protocol.InventoryResponse,
	cancel: (EquipTransition) -> (),
	forceUnequip: (EquipTransition) -> (),
	destroy: (EquipTransition) -> (),
}

export type State = {
	player: Player,
	root: Folder,
	hotbar: Folder,
	storage: Folder,
	storedTools: Folder,
	storageCapacity: number,
	materials: { [string]: number },
	index: { [string]: IndexEntry },
	queue: TransactionQueue,
	connections: { [string]: RBXScriptConnection? },
	currentSlot: number?,
	removing: boolean,
	enabled: boolean,
	disabledReason: string?,
	ensureStorageSlots: (number) -> (),
	replica: Replica?,
	equipTransition: EquipTransition?,
}

export type Placement = {
	resetTransients: (Instance) -> (),
	moveToOwner: (Model, Folder) -> (),
	moveToWorld: (Model, Folder, CFrame) -> (),
}

export type Templates = {
	folder: Folder,
	getConfig: (Templates, string) -> BaseConfig?,
	getTemplate: (Templates, string) -> Model?,
	validate: (Templates, string) -> (boolean, string?),
	validateMaterial: (Templates, string) -> (boolean, string?),
	isComplete: (Templates, Model) -> boolean,
}

export type ItemFactory = {
	templates: Templates,
	resetTransients: (ItemFactory, Instance) -> (),
	create: (ItemFactory, string, CreateRecord?) -> Model,
	materialize: (ItemFactory, protocol.ItemRecord) -> Model,
	adoptWorldItem: (ItemFactory, Model) -> (Model?, string?),
	replaceClone: (ItemFactory, Model, string) -> Model,
	repair: (ItemFactory, Model) -> Model?,
	destroy: (ItemFactory, Instance) -> (),
}

export type ProjectileCosmetics = {
	templates: Templates,
	folder: Folder,
	ensure: (ProjectileCosmetics, string) -> Model?,
}

export type WorldItems = {
	folder: Folder,
	factory: ItemFactory,
	claims: { [Model]: Player },
	adoptExisting: (WorldItems) -> (),
	claim: (WorldItems, Model, Player) -> boolean,
	release: (WorldItems, Model) -> (),
}

export type AllocationChange = {
	zone: protocol.Zone,
	index: number,
	item: Model?,
}

export type Allocation = {
	granted: number,
	remaining: number,
	changes: { AllocationChange },
	items: { protocol.ItemDescriptor },
}

export type PersistenceStore = {
	write: (PersistenceStore, Player, State) -> boolean,
	default: (PersistenceStore) -> SerializedInventory,
	validateCapacity: (PersistenceStore, unknown) -> number,
}

export type Hydrator = {
	factory: ItemFactory,
	persistence: PersistenceStore,
	_loadZone: (Hydrator, Player, State, protocol.Zone, unknown, { [string]: boolean }) -> (),
	load: (Hydrator, Player, State) -> boolean,
}

export type ControllerMethod = (ToolController, ...unknown) -> unknown

export type ToolController = {
	[string]: unknown,
	player: Player,
	destroy: ((ToolController) -> ())?,
	cleanupCharging: ((ToolController) -> ())?,
	cancelSwing: ((ToolController) -> ())?,
	stopActiveSound: ((ToolController) -> ())?,
	registerToggle: ((ToolController) -> ())?,
	cleanupRigArtifacts: ((ToolController) -> ())?,
	prepareEquip: ((ToolController) -> ())?,
	unequip: ((ToolController) -> ())?,
	equip: ((ToolController) -> ())?,
}

export type ControllerHost = {
	controllers: { [Instance]: ToolController },
	create: (ControllerHost, Player, Model, Model) -> ToolController?,
	get: (ControllerHost, Instance?) -> ToolController?,
	reset: (ControllerHost, Model, Folder?) -> (),
	destroy: (ControllerHost, Instance?) -> (),
	destroyForPlayer: (ControllerHost, Player) -> (),
}

export type ProjectileCast = {
	Terminate: (ProjectileCast) -> (),
}

export type ProjectileData = {
	origin: Vector3,
	direction: Vector3?,
	velocity: number,
	projectileId: string,
	projectileObject: BasePart | Model,
	filterDescendantsInstances: { Instance }?,
	startTime: number?,
	specialInfo: {
		trueId: string?,
	},
}

export type ProjectileHooks = {
	onRayHit: ((unknown, RaycastResult, Vector3, Instance?) -> ())?,
	onCastTerminated: ((unknown) -> ())?,
}

export type ProjectileController = {
	createProjectile: (ProjectileData, ProjectileHooks?) -> ProjectileCast,
}

export type InventoryApi = {
	getState: (InventoryApi, Player) -> State?,
	getSlot: (InventoryApi, State, protocol.Zone, number) -> ObjectValue?,
	rebuildIndex: (InventoryApi, State) -> (),
	withLock: (InventoryApi, Player, TransactionCallback) -> ...unknown,
	commit: (
		InventoryApi,
		Player,
		{ AllocationChange },
		{
			storageCapacity: number?,
			currentSlot: number?,
			clearCurrentSlot: boolean?,
			materialChanges: { [string]: number }?,
		}?
	) -> (),
	unequipIfNeeded: (InventoryApi, Player, string) -> boolean,
}

export type GrantResult = {
	ok: boolean,
	code: protocol.ResponseCode,
	granted: number,
	remaining: number,
	items: { protocol.ItemDescriptor },
}

export type Grant = {
	inventory: InventoryApi,
	factory: ItemFactory,
	placement: Placement,
	_emptyResult: (Grant, protocol.ResponseCode) -> GrantResult,
	giveItem: (Grant, Player, string, number?, PersistentAttributes?) -> GrantResult,
	addItem: (Grant, Player, protocol.ItemRecord) -> GrantResult,
	giveToSlot: (Grant, Player, protocol.ItemRecord, protocol.Zone, number) -> protocol.InventoryResponse,
}

export type PendingThrow = {
	player: Player,
	character: Model,
	item: Model,
	itemId: string,
	itemType: string,
	origin: Vector3,
	direction: Vector3,
	velocity: number,
	projectileId: string,
	deadline: number,
	launched: boolean,
	finalized: boolean,
}

export type PendingThrows = {
	inventory: InventoryApi,
	factory: ItemFactory,
	cosmetics: ProjectileCosmetics,
	toolHost: ControllerHost,
	projectiles: ProjectileController,
	folder: Folder,
	pending: { [string]: PendingThrow },
	_finalize: (PendingThrows, string) -> (),
	_launch: (PendingThrows, string) -> boolean,
	throw: (PendingThrows, Player, protocol.ThrowPayload) -> protocol.InventoryResponse,
	release: (PendingThrows, Player, protocol.ReleaseThrowPayload) -> protocol.InventoryResponse,
	destroyForPlayer: (PendingThrows, Player) -> (),
}

export type ReplicaFactory = {
	new: (Player, State) -> Replica,
}

export type Service = InventoryApi & {
	requestRemote: RemoteFunction,
	states: { [Player]: State },
	templates: Templates,
	factory: ItemFactory,
	placement: Placement,
	projectileCosmetics: ProjectileCosmetics,
	worldItems: WorldItems,
	persistence: PersistenceStore,
	hydrator: Hydrator,
	replica: ReplicaFactory,
	toolHost: ControllerHost,
	pendingThrows: PendingThrows,
	grants: Grant,
	gateway: Gateway,
	withPlayerAction: (Service, Player, () -> protocol.InventoryResponse) -> protocol.InventoryResponse,
	commit: (
		InventoryApi,
		Player,
		{ AllocationChange },
		{
			storageCapacity: number?,
			currentSlot: number?,
			clearCurrentSlot: boolean?,
			materialChanges: { [string]: number }?,
		}?
	) -> (),
	loadForPlayer: (Service, Player) -> boolean,
	unloadForPlayer: (Service, Player) -> (),
	giveItem: (Service, Player, string, number?, PersistentAttributes?) -> GrantResult,
	giveMaterial: (Service, Player, string, number) -> GrantResult,
	addItem: (Service, Player, protocol.ItemRecord) -> GrantResult,
	giveToSlot: (Service, Player, protocol.ItemRecord, protocol.Zone, number) -> protocol.InventoryResponse,
	setEnabled: (Service, Player, boolean, string?) -> protocol.InventoryResponse,
	isEnabled: (Service, Player) -> boolean,
	equip: (Service, Player, number?) -> protocol.InventoryResponse,
	forceUnequip: (Service, Player) -> (),
	pickupWorldItem: (Service, Player, Model, Instance?) -> protocol.InventoryResponse,
	destroy: (Service) -> (),
}

export type RateLimiter = {
	maximum: number,
	windowSeconds: number,
	buckets: { [Player]: { startedAt: number, count: number } },
	consume: (RateLimiter, Player) -> boolean,
	clear: (RateLimiter, Player) -> (),
	destroy: (RateLimiter) -> (),
}

export type RouterHandler = (Player, protocol.ActionPayload) -> protocol.InventoryResponse

export type Router = {
	actions: { [string]: RouterHandler },
	route: (Router, Player, protocol.ActionPayload) -> protocol.InventoryResponse,
}

export type Gateway = {
	service: Service,
	remote: RemoteFunction,
	limiter: RateLimiter,
	router: Router,
	_invoke: (Gateway, Player, unknown) -> protocol.InventoryResponse,
	clear: (Gateway, Player) -> (),
	destroy: (Gateway) -> (),
}

return table.freeze({})
