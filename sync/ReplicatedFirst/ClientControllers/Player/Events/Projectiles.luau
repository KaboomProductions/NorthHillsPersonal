local projectilesController = {}
projectilesController.__index = projectilesController

local replicatedStorage = game:GetService("ReplicatedStorage")
local sharedAssets = replicatedStorage.SharedAssets
local dictionaries = sharedAssets.Dictionaries
local projectileDefinitions = dictionaries.ProjectileDefinitions

local communication = replicatedStorage.Communication
local networking = require(communication.Networking)

local sharedClasses = replicatedStorage.SharedClasses
local fastCast = require(sharedClasses.Fastcast)
fastCast.VisualizeCasts = false

local ignore = workspace.Ignore
local projectilesContainer = ignore.Projectiles

local mainCast = fastCast.new()

export type projectileData = {
	origin: Vector3,
	direction: Vector3,
	velocity: number,
	projectileId: string?,
	projectileObject: BasePart | Model,
	filterDescendantsInstances: { Instance }?,
	startTime: number?,

	specialInfo: {
		trueId: string?,
	},
}

function projectilesController:onReplicationEvent(data: projectileData)
	local foundDefinition = projectileDefinitions[data.projectileId]
	local requiredDefinition = require(foundDefinition)
	local behavior = fastCast.newBehavior()
	behavior.CosmeticBulletContainer = projectilesContainer
	behavior.AutoIgnoreContainer = true

	local delta = workspace:GetServerTimeNow() - data.startTime
	local offset = data.direction * data.velocity * delta
	local adjustedOrigin = data.origin + offset

	if not requiredDefinition.castBehavior.CosmeticBulletTemplate and data.projectileObject then
		behavior.CosmeticBulletTemplate = data.projectileObject
	end

	for property, value in pairs(requiredDefinition.castBehavior) do
		behavior[property] = value
	end
	if data.filterDescendantsInstances then
		local raycastParams = RaycastParams.new()
		raycastParams.RespectCanCollide = true
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = data.filterDescendantsInstances
		behavior.RaycastParams = raycastParams
	end

	local firedCast = mainCast:Fire(adjustedOrigin, data.direction, data.velocity, behavior)
	firedCast.UserData = {
		id = data.projectileId,
		definition = requiredDefinition,
		specialInfo = data.specialInfo,
	}

	task.spawn(requiredDefinition.onStartup, firedCast)

	return firedCast
end

function projectilesController:onLengthChanged(cast, lastPoint, direction, length, segmentVelocity, projectile)
	local userData = cast.UserData
	local definition = userData.definition

	if definition.onLengthChanged ~= nil then
		definition.onLengthChanged(cast, lastPoint, direction, length, segmentVelocity, projectile)
	end
end

function projectilesController:onRayHit(cast, raycastResult, segmentVelocity, bullet)
	local userData = cast.UserData
	local definition = userData.definition

	if definition.onRayHit ~= nil then
		definition.onRayHit(cast, raycastResult, segmentVelocity, bullet)
	end
end

function projectilesController:onCastTerminated(cast)
	local userData = cast.UserData
	local definition = userData.definition

	if definition.onCastTerminated ~= nil then
		definition.onCastTerminated(cast)
	end
end

function projectilesController:init()
	self.connections.onReplicationEvent = networking.events.replicateProjectile.OnClientEvent:Connect(
		function(data: projectileData)
			self:onReplicationEvent(data)
		end
	)

	self.connections.onLengthChanged = mainCast.LengthChanged:Connect(
		function(cast, lastPoint, direction, length, segmentVelocity, projectile)
			self:onLengthChanged(cast, lastPoint, direction, length, segmentVelocity, projectile)
		end
	)

	self.connections.onRayHit = mainCast.RayHit:Connect(function(cast, raycastResult, segmentVelocity, bullet)
		self:onRayHit(cast, raycastResult, segmentVelocity, bullet)
	end)

	self.connections.onCastTerminated = mainCast.CastTerminating:Connect(function(cast)
		self:onCastTerminated(cast)
	end)
end

function projectilesController.new()
	local self = setmetatable({}, projectilesController)
	self.connections = {}

	task.defer(self.init, self)

	return self
end

function projectilesController:destroy()
	for connectionName, connection in self.connections do
		connection:Disconnect()
		self.connections[connectionName] = nil
	end

	setmetatable(self, nil)
end

return projectilesController
