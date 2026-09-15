local mainAttackerController = {}
mainAttackerController.__index = mainAttackerController

function mainAttackerController:preload()
	for _, controller in script:GetChildren() do
		if not controller:IsA("ModuleScript") or controller:HasTag("Ignored") then
			continue
		end

		controller = require(controller)
		self.childControllers[#self.childControllers + 1] = controller.new(self)
	end

	self.targetsController = require(script.Targets).new(self)
end

function mainAttackerController:init()
	self:preload()

	task.spawn(function()
		while getmetatable(self) do
			local deltaTime = task.wait(1 / 10)
			self.targetsController:update(deltaTime)

			for _, controller in self.childControllers do
				if not getmetatable(controller) then
					continue
				end

				controller:update(deltaTime)
			end
		end
	end)
end

function mainAttackerController.new(controller: { agent: Model, config: any, sounds: any, [string]: any })
	local self = setmetatable({}, mainAttackerController)

	self.controller = controller
	self.agent = self.controller.agent
	self.rootPart = self.controller.rootPart

	self.connections = {}
	self.childControllers = {}

	self.tracks = self.controller.tracks
	self.lightAttackTracks = self.tracks.lightAttack
	self.heavyAttackTracks = self.tracks.heavyAttack
	self.pushTracks = self.tracks.push
	self.backhandTracks = self.tracks.backhand

	self.sounds = self.controller.sounds

	self.pushSounds = self.sounds.Push
	self.primaryPushSounds = self.pushSounds.Primary:GetChildren()
	self.secondaryPushSounds = self.pushSounds.Secondary:GetChildren()

	self.attackSounds = self.sounds.Attack
	self.swingSounds = self.attackSounds.Swing:GetChildren()
	self.lightHitSounds = self.attackSounds.LightHit:GetChildren()
	self.heavyHitSounds = self.attackSounds.HeavyHit:GetChildren()

	self.sharedConfig = self.controller.config.shared
	self.combatConfig = self.controller.config.combat

	task.spawn(self.init, self)

	return self
end

function mainAttackerController:destroy()
	for connectionName, connection in self.connections do
		connection:Disconnect()
		self.connections[connectionName] = nil
	end

	self.targetsController:destroy()

	for _, controller in self.childControllers do
		controller:destroy()
	end

	table.clear(self.childControllers)
	table.clear(self.connections)

	setmetatable(self, nil)
end

return mainAttackerController
