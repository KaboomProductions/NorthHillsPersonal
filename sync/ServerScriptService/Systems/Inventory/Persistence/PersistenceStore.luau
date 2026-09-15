--!strict

local serverScriptService = game:GetService("ServerScriptService")

local playerData = require(serverScriptService.GameHandler.PlayerData)
local codec = require(script.Parent.InventoryCodec)
local types = require(script.Parent.Parent.Contracts)
local playerState = require(script.Parent.Parent.State.PlayerState)

export type Store = types.PersistenceStore
type State = playerState.State

local persistenceStore = {}
persistenceStore.__index = persistenceStore

function persistenceStore.new(): Store
	return (
		setmetatable({
			write = persistenceStore.write,
			default = persistenceStore.default,
			validateCapacity = persistenceStore.validateCapacity,
		}, persistenceStore) :: unknown
	) :: Store
end

function persistenceStore:write(player: Player, state: State): boolean
	local data = playerData.get(player)
	if data == nil then
		error(
			string.format("[Inventory] Cannot persist inventory for %s: PlayerData profile is unavailable", player.Name)
		)
	end
	data.Inventory = codec.serialize(state)
	return true
end

function persistenceStore:default(): types.SerializedInventory
	return codec.default()
end

function persistenceStore:validateCapacity(value: unknown): number
	return codec.validateCapacity(value)
end

return persistenceStore
