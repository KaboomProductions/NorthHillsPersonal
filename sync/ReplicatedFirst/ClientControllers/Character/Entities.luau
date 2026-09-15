local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local players = game:GetService("Players")

local player = players.LocalPlayer

local sharedAssets = replicatedStorage.SharedAssets
local dictionaries = sharedAssets.Dictionaries
local chaseProfiles = dictionaries.ChaseProfiles:GetChildren()

local effects = script.Effects
local profileControllers = script.ProfileControllers:GetChildren()
local _utils = script.Utils:GetChildren()

local components = workspace.Components
local entities = components.Entities

local entitiesController = {}
entitiesController.__index = entitiesController
entitiesController.__vars = {
	defaultRange = 70,
}

function entitiesController:preload()
	for _, profile in chaseProfiles do
		if not profile:IsA("ModuleScript") then
			continue
		end

		self.trueProfiles[profile.Name] = require(profile)
	end

	for _, controller in profileControllers do
		if not controller:IsA("ModuleScript") then
			continue
		end

		self.trueProfileControllers[controller.Name] = require(controller).new()
	end
end

function entitiesController:getEffect(effectName: string)
	if not self.effectInstances[effectName] then
		local module = effects:FindFirstChild(effectName)
		self.effectInstances[effectName] = require(module).new()
	end

	return self.effectInstances[effectName]
end

function entitiesController:getProfileController(profileId: string)
	return self.trueProfileControllers[profileId]
end

function entitiesController:registerChase(entity: Model)
	local profileId = entity.Name
	local targets = entity:FindFirstChild("Targets")
	local cacheEntry = targets and targets:FindFirstChild(tostring(player.UserId))
	local chaseProfile = self.trueProfiles[profileId]

	if chaseProfile then
		self.activeChasers[entity] = {
			profile = chaseProfile,
			cacheEntry = cacheEntry,
		}

		self:resolveChase()
	end
end

function entitiesController:unregisterChase(entity: Model)
	if self.activeChasers[entity] then
		self.activeChasers[entity] = nil
		self:resolveChase()
	end
end

function entitiesController:switchChaser(entity: Model, profile: { effects: { string } })
	if self.afterChaseController then
		local outgoing = self.afterChaseController
		self.afterChaseController = nil

		if outgoing.cancelAfterProfile then
			outgoing:cancelAfterProfile()
		else
			outgoing:stop()
		end
	end

	if self.currentChaser and self.currentProfile then
		for _, effectName in self.currentProfile.effects do
			self:getEffect(effectName):stop()
		end

		local outgoingController = self:getProfileController(self.currentChaser.Name)

		if not entity and outgoingController.loadAfterProfile then
			outgoingController:loadAfterProfile()
			self.afterChaseController = outgoingController
		else
			outgoingController:stop()
		end
	end

	self.currentChaser = entity
	self.currentProfile = profile

	if entity and profile then
		for _, effectName in profile.effects do
			self:getEffect(effectName):start(profile)
		end

		self:getProfileController(entity.Name):start(profile, entity)
	end
end

function entitiesController:resolveChase()
	local currentWinner = nil
	local winnerData = nil

	for entity, chaserData in self.activeChasers do
		local profile = chaserData.profile
		local isBetter = currentWinner == nil
			or profile.priority > winnerData.profile.priority
			or (profile.priority == winnerData.profile.priority and entity == self.currentChaser)

		if isBetter then
			currentWinner = entity
			winnerData = chaserData
		end
	end

	if currentWinner ~= self.currentChaser then
		self:switchChaser(currentWinner, winnerData and winnerData.profile)
	end
end

function entitiesController:hookEntity(entity: Model)
	local targets = entity:FindFirstChild("Targets")
	local userId = tostring(player.UserId)

	table.insert(
		self.connections,
		targets.ChildAdded:Connect(function(child)
			if child.Name == userId then
				self:registerChase(entity)
			end
		end)
	)

	table.insert(
		self.connections,
		targets.ChildRemoved:Connect(function(child)
			if child.Name == userId then
				self:unregisterChase(entity)
			end
		end)
	)

	if targets:FindFirstChild(userId) then
		self:registerChase(entity)
	end

	table.insert(
		self.connections,
		entity.AncestryChanged:Connect(function(_, parent)
			if not parent then
				self:unregisterChase(entity)
			end
		end)
	)
end

function entitiesController:init()
	self:preload()

	for _, entity in entities:GetChildren() do
		self:hookEntity(entity)
	end

	self.connections.onEntityAdded = entities.ChildAdded:Connect(function(entity)
		self:hookEntity(entity)
	end)

	self.connections.onUpdate = runService.RenderStepped:Connect(function(deltaTime: number)
		self:update(deltaTime)
	end)
end

function entitiesController.new()
	local self = setmetatable({}, entitiesController)

	self.connections = {}
	self.trueProfiles = {}
	self.trueProfileControllers = {}
	self.activeChasers = {}
	self.effectInstances = {}

	task.spawn(self.init, self)

	return self
end

function entitiesController:update(deltaTime: number)
	if self.currentChaser and self.currentProfile then
		local chaserData = self.activeChasers[self.currentChaser]
		local targetDistance = chaserData and chaserData.cacheEntry:GetAttribute("Distance")

		if not targetDistance then
			self:unregisterChase(self.currentChaser)
		else
			self.lastIntensity = 1
				- math.clamp(
					(targetDistance - self.currentProfile.minDistance)
						/ (
							(self.currentChaser:GetAttribute("Range") or self.__vars.defaultRange)
							- self.currentProfile.minDistance
						),
					0,
					1
				)
		end
	end

	for _, controller in self.trueProfileControllers do
		controller:update(deltaTime, self.lastIntensity)
	end

	for _, effectInstance in self.effectInstances do
		effectInstance:update(deltaTime, self.lastIntensity)
	end
end

function entitiesController:destroy()
	for _, connection in self.connections do
		connection:Disconnect()
	end

	table.clear(self.connections)
	table.clear(self.trueProfiles)
	table.clear(self.activeChasers)
	table.clear(self.effectInstances)
	table.clear(self.trueProfileControllers)

	setmetatable(self, nil)
end

return entitiesController
