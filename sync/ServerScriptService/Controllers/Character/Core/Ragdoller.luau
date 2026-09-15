local runService = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local serverStorage = game:GetService("ServerStorage")

local serverAssets = serverStorage.ServerAssets
local classes = serverAssets.Classes
local ragdollController = require(classes.Ragdoll)

local communication = replicatedStorage.Communication
local networking = require(communication.Networking)

local ragdollerController = {}
ragdollerController.__index = ragdollerController

function ragdollerController:preload()
	self.humanoid = self.character:FindFirstChildOfClass("Humanoid")
	self.humanoidRootPart = self.humanoid and self.humanoid.RootPart
		or self.character:FindFirstChild("HumanoidRootPart")

	self.mainRagdoller = ragdollController.new(self.character, "R6")

	networking.events.ragdollUpdate:FireClient(self.player, false)
end

function ragdollerController:init()
	self:preload()

	self.connections.onTimerChanged = self.character:GetAttributeChangedSignal("RagdollTimer"):Connect(function()
		local timer = self.character:GetAttribute("RagdollTimer")

		if timer <= 0 then
			self.character:SetAttribute("Ragdolled", false)
			return
		end

		if self._countingDown then
			return
		end

		self._countingDown = true

		self.character:SetAttribute("Ragdolled", true)

		local character = self.character
		self.timerThread = task.spawn(function()
			local newTimer = 0

			repeat
				local _, deltaTime = runService.Stepped:Wait()

				if getmetatable(self) == nil or character.Parent == nil then
					return
				end

				newTimer = (character:GetAttribute("RagdollTimer") or 0) - deltaTime
				character:SetAttribute("RagdollTimer", newTimer)
			until newTimer <= 0 or not character:GetAttribute("Ragdolled")

			self._countingDown = false
			self.timerThread = nil

			character:SetAttribute("Ragdolled", false)
			character:SetAttribute("RagdollTimer", 0)
		end)
	end)

	self.connections.onRagdollChanged = self.character:GetAttributeChangedSignal("Ragdolled"):Connect(function()
		self.currentValue = self.character:GetAttribute("Ragdolled")

		networking.events.ragdollUpdate:FireClient(self.player, self.currentValue)

		if self.currentValue then
			self.mainRagdoller:enable()
		else
			self.mainRagdoller:disable()
		end
	end)
end

function ragdollerController.new(player: Player, character: Model)
	local self = setmetatable({}, ragdollerController)

	self.player = player
	self.character = character
	self.connections = {}

	task.defer(self.init, self)

	return self
end

function ragdollerController:destroy()
	local connections = self.connections

	for _, connection in pairs(connections) do
		connection:Disconnect()
	end

	local timerThread = self.timerThread
	if timerThread and coroutine.running() ~= timerThread then
		task.cancel(timerThread)
	end
	self.timerThread = nil

	local mainRagdoller = self.mainRagdoller
	if mainRagdoller then
		local didDestroy, destroyError = pcall(mainRagdoller.destroy, mainRagdoller)
		if not didDestroy then
			warn("[Ragdoller] Ragdoll destroy failed:", destroyError)
		end
		self.mainRagdoller = nil
	end

	table.clear(connections)
	table.clear(self)
	setmetatable(self, nil)
end

return ragdollerController
