export type entityStateMap = { [string]: boolean }
export type controllerList = { unknown }

export type clientRuntimeState = {
	rng: Random,
	hasLoadedPlayerControllers: boolean,
	entityStatesById: entityStateMap,
	activePlayerControllers: controllerList,
	activeCharacterControllers: controllerList,
}

local clientRuntime: clientRuntimeState = {
	rng = Random.new(),
	hasLoadedPlayerControllers = false,
	entityStatesById = {} :: entityStateMap,
	activePlayerControllers = {} :: controllerList,
	activeCharacterControllers = {} :: controllerList,
}

return clientRuntime
