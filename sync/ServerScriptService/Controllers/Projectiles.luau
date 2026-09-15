local projectilesController = {}

local replicatedStorage = game:GetService("ReplicatedStorage")

local sharedAssets = replicatedStorage.SharedAssets
local dictionaries = sharedAssets.Dictionaries
local projectileDefinitions = dictionaries.ProjectileDefinitions

local communication = replicatedStorage.Communication
local networking = require(communication.Networking)

local sharedClasses = replicatedStorage.SharedClasses
local fastCast = require(sharedClasses.Fastcast)
fastCast.VisualizeCasts = false

local behaviorParams = RaycastParams.new()
behaviorParams.RespectCanCollide = true
behaviorParams.FilterType = Enum.RaycastFilterType.Exclude
behaviorParams.FilterDescendantsInstances = {}

local mainCast = fastCast.new()

export type projectileData = {
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

export type serverHooks = {
	onRayHit: ((any, RaycastResult, Vector3, Instance?) -> ())?,
	onCastTerminated: ((any) -> ())?,
}

local function callSafely(label: string, callback, ...)
	if callback == nil then
		return
	end
	local ok, message = pcall(callback, ...)
	if not ok then
		warn(string.format("[Projectiles] %s failed: %s", label, tostring(message)))
	end
end

function projectilesController.onLengthChanged(cast, lastPoint, direction, length, segmentVelocity, projectile)
	local userData = cast.UserData
	local definition = userData.definition

	callSafely(
		"definition.onLengthChanged",
		definition.onLengthChanged,
		cast,
		lastPoint,
		direction,
		length,
		segmentVelocity,
		projectile
	)
end

function projectilesController.onRayHit(cast, raycastResult, segmentVelocity, bullet)
	local userData = cast.UserData
	local definition = userData.definition

	callSafely("definition.onRayHit", definition.onRayHit, cast, raycastResult, segmentVelocity, bullet)
	callSafely(
		"serverHooks.onRayHit",
		userData.serverHooks and userData.serverHooks.onRayHit,
		cast,
		raycastResult,
		segmentVelocity,
		bullet
	)
end

function projectilesController.onCastTerminated(cast)
	local userData = cast.UserData
	local definition = userData.definition

	callSafely("definition.onCastTerminated", definition.onCastTerminated, cast)
	callSafely("serverHooks.onCastTerminated", userData.serverHooks and userData.serverHooks.onCastTerminated, cast)
end

function projectilesController.createProjectile(data: projectileData, hooks: serverHooks?)
	local foundDefinition = projectileDefinitions[data.projectileId]
	assert(foundDefinition and foundDefinition:IsA("ModuleScript"), "Unknown projectile definition")
	local requiredDefinition = require(foundDefinition)
	local behavior = fastCast.newBehavior()

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

	if data.projectileObject ~= nil then
		if data.projectileObject:IsA("BasePart") then
			data.projectileObject.Anchored = true
		end

		for _, part in pairs(data.projectileObject:GetChildren()) do
			if not part:IsA("BasePart") then
				continue
			end

			part.Anchored = true
		end
	end

	data.startTime = workspace:GetServerTimeNow()
	local firedCast = mainCast:Fire(data.origin, data.direction, data.velocity, behavior)
	networking.events.replicateProjectile:FireAllClients(data)

	firedCast.UserData = {
		id = data.projectileId,
		definition = requiredDefinition,
		serverHooks = hooks,
	}

	return firedCast
end

function projectilesController.init()
	mainCast.LengthChanged:Connect(projectilesController.onLengthChanged)
	mainCast.RayHit:Connect(projectilesController.onRayHit)
	mainCast.CastTerminating:Connect(projectilesController.onCastTerminated)
end

return projectilesController
