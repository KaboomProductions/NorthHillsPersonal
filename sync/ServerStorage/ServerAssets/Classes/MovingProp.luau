local players = game:GetService("Players")

local config = require(script.Config)
local hitboxLifecycle = require(script.HitboxLifecycle)
local velocityDamage = require(script.VelocityDamage)

local ignore = workspace.Ignore

local movingPropController = {}
movingPropController.__index = movingPropController

export type movingPropController = typeof(setmetatable(
	{} :: {
		prop: BasePart,
		connections: { [string]: RBXScriptConnection },
		hitHumanoids: { [Humanoid]: boolean },

		overlapParams: OverlapParams,

		hitbox: any,

		__config: { any },
	},
	movingPropController
))

function movingPropController:startHitbox()
	self.hitbox = hitboxLifecycle.start(self.prop, self.overlapParams, self.__config.sizeMultiplier)
	return self.hitbox
end

function movingPropController:stopHitbox()
	local connections = self.connections

	if connections.hitboxTouched then
		connections.hitboxTouched:Disconnect()
		connections.hitboxTouched = nil
	end

	hitboxLifecycle.stop(self.hitbox)
	self.hitbox = nil
end

function movingPropController:updateHitbox(_deltaTime)
	hitboxLifecycle.update(self.hitbox, self.prop)
end

function movingPropController:getVelocityMagnitude(): number
	local velocity = self.prop:GetVelocityAtPosition(self.prop.Position)

	return velocity.Magnitude
end

function movingPropController:canDamageFromVelocity(): boolean
	local velocityMagnitude = self:getVelocityMagnitude()

	return velocityDamage.isAboveVelocityThreshold(velocityMagnitude, self.__config.minimumDamageVelocity)
end

function movingPropController:calculateDamage(): number
	local velocityMagnitude = self:getVelocityMagnitude()
	local damageConfig = self.__config

	return velocityDamage.calculateDamageFromVelocity({
		baseDamage = damageConfig.baseDamage,
		maximumDamage = damageConfig.maximumDamage,

		minimumVelocity = damageConfig.damageVelocityMinimum,
		maximumVelocity = damageConfig.damageVelocityMaximum,

		velocity = velocityMagnitude,
	})
end

function movingPropController:damageHumanoid(humanoid: Humanoid)
	if self.hitHumanoids[humanoid] then
		return
	end

	if not self:canDamageFromVelocity() then
		return
	end

	if not players:GetPlayerFromCharacter(humanoid.Parent) then --// guard against killing phil
		return
	end

	self.hitHumanoids[humanoid] = true
	humanoid:TakeDamage(self:calculateDamage())

	--// TODO: add ragdoll once ragdoll system and shit exists
end

function movingPropController:onHitboxTouched(humanoid: Humanoid?)
	if not humanoid then
		return
	end

	self:damageHumanoid(humanoid)
end

function movingPropController:update(deltaTime: number)
	if not getmetatable(self) then
		return
	end

	local velocityMagnitude = self:getVelocityMagnitude()
	local angularVelocity = vector.magnitude(self.prop.AssemblyAngularVelocity)

	self:updateHitbox()

	if
		velocityMagnitude < self.__config.destroyVelocityThreshold
		and angularVelocity < self.__config.destroyAngularVelocityThreshold
	then
		self.stationaryTime = self.stationaryTime + deltaTime

		if self.stationaryTime >= 0.5 then
			self:destroy()
		end
	else
		self.stationaryTime = 0
	end
end

function movingPropController:initialize()
	local hitbox = self:startHitbox()
	self.prop.Anchored = false

	self.connections.hitboxTouched = hitbox.Touched:Connect(function(_hitpart, humanoid: Humanoid)
		self:onHitboxTouched(humanoid)
	end)

	task.spawn(function()
		while getmetatable(self) do
			local deltaTime = task.wait(1 / 10)
			self:update(deltaTime)
		end
	end)
end

function movingPropController.new(prop: BasePart): movingPropController
	local self = setmetatable({}, movingPropController)

	self.prop = prop
	self.connections = {}
	self.hitHumanoids = {}

	self.stationaryTime = 0

	self.overlapParams = OverlapParams.new()
	self.overlapParams.FilterDescendantsInstances = { ignore }
	self.overlapParams.FilterType = Enum.RaycastFilterType.Exclude

	self.__config = config

	task.spawn(self.initialize, self)

	return self
end

function movingPropController:destroy()
	self.prop.Anchored = true

	self:stopHitbox()

	for index, connection in pairs(self.connections) do
		connection:Disconnect()
		self.connections[index] = nil
	end

	setmetatable(self, nil)
end

return movingPropController
