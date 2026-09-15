--!strict

local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local itemUtils = require(replicatedStorage.SharedUtilities.ItemUtils)
local protocol = require(replicatedStorage.SharedUtilities.InventoryProtocol)
local InventoryStore = require(script.Parent.Parent.InventoryStore)
local InventoryRequests = require(script.Parent.InventoryRequests)

local throwFlow = {}
throwFlow.__index = throwFlow

type ThrowData = {
	throwId: string,
	deadline: number,
}

export type ThrowFlow = {
	player: Player,
	requests: InventoryRequests.Requests?,
	store: InventoryStore.Store?,
	markerConnection: RBXScriptConnection?,
	track: AnimationTrack?,
	animation: Animation?,
	throwId: string?,
	generation: number,
	_clearPending: (self: ThrowFlow) -> (),
	_release: (self: ThrowFlow, throwId: string, generation: number) -> (),
	throw: (self: ThrowFlow, itemId: string) -> (),
	destroy: (self: ThrowFlow) -> (),
}

function throwFlow.new(requests: InventoryRequests.Requests, store: InventoryStore.Store): ThrowFlow
	local self = (
		setmetatable({
			player = players.LocalPlayer,
			requests = requests,
			store = store,
			markerConnection = nil,
			track = nil,
			animation = nil,
			throwId = nil,
			generation = 0,
		}, throwFlow) :: unknown
	) :: ThrowFlow
	return self
end

function throwFlow._clearPending(self: ThrowFlow): ()
	if self.markerConnection then
		self.markerConnection:Disconnect()
		self.markerConnection = nil
	end
	if self.track then
		pcall(self.track.Stop, self.track)
		self.track = nil
	end
	if self.animation then
		self.animation:Destroy()
		self.animation = nil
	end
	self.throwId = nil
end

function throwFlow._release(self: ThrowFlow, throwId: string, generation: number): ()
	if generation ~= self.generation or self.throwId ~= throwId then
		return
	end
	self:_clearPending()
	local requests = self.requests
	if requests then
		requests:releaseThrow(throwId)
	end
end

function throwFlow.throw(self: ThrowFlow, itemId: string): ()
	local store = self.store
	local requests = self.requests
	if store == nil or requests == nil or not store:isEnabled() then
		return
	end
	local currentState = store.state()
	local descriptor: protocol.ItemDescriptor? = nil
	if currentState.currentSlot ~= nil then
		descriptor = currentState.hotbar[tostring(currentState.currentSlot)]
	end
	local direction = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.LookVector or Vector3.zAxis
	local response = requests:throw(itemId, direction)
	if response == nil or not response.ok or typeof(response.data) ~= "table" then
		return
	end
	local data = response.data :: { [string]: unknown }
	if typeof(data.throwId) ~= "string" or typeof(data.deadline) ~= "number" then
		return
	end
	local throwData: ThrowData = {
		throwId = data.throwId,
		deadline = data.deadline,
	}
	self:_clearPending()
	self.throwId = throwData.throwId
	self.generation += 1
	local generation = self.generation
	local throwable = if descriptor then itemUtils.getThrowableConfig(descriptor.itemType) else nil
	local animationId = throwable and throwable.animationId
	local releaseMarker = throwable and throwable.releaseMarker or "Release"
	local character = self.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator and (typeof(animationId) == "string" or typeof(animationId) == "number") then
		local animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://" .. tostring(animationId)
		local track = animator:LoadAnimation(animation)
		local markerConnection = track:GetMarkerReachedSignal(releaseMarker):Connect(function()
			self:_release(throwData.throwId, generation)
		end)
		self.animation = animation
		self.track = track
		self.markerConnection = markerConnection
		track:Play()
	end
	task.delay(math.max(throwData.deadline - workspace:GetServerTimeNow(), 0), function()
		self:_release(throwData.throwId, generation)
	end)
end

function throwFlow.destroy(self: ThrowFlow): ()
	self.generation += 1
	self:_clearPending()
	self.requests = nil
	self.store = nil
end

return throwFlow
