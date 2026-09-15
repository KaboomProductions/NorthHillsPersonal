local propAttackerController = {}
propAttackerController.__index = propAttackerController

local serverStorage = game:GetService("ServerStorage")

local serverAssets = serverStorage.ServerAssets
local serverClasses = serverAssets.Classes
local movingPropController = require(serverClasses.MovingProp)

local gameFolder = workspace.Game
local mapFolder = gameFolder.Map

function propAttackerController.new(ancestorInfo)
	local self = setmetatable({}, propAttackerController)

	self.ancestor = ancestorInfo
	self.connections = self.ancestor.connections
	self.sharedConfig = self.ancestor.sharedConfig
	self.combatConfig = self.ancestor.combatConfig

	self.backhandTracks = self.ancestor.backhandTracks

	self.controller = self.ancestor.controller
	self.agent = self.ancestor.agent
	self.rootPart = self.ancestor.rootPart

	self.availableProps = mapFolder.Props:GetDescendants()

	return self
end

function propAttackerController:fetchProps(maxDistance: number?): { BasePart }
	local root = self.rootPart
	local lookVector = root.CFrame.LookVector

	local propsToHit = {}
	local nearestProp = nil
	local closestDistance = math.huge

	for _, prop in self.availableProps do
		if not prop:IsA("BasePart") then
			continue
		end

		local offset = (prop.Position - root.Position)
		local distance = vector.magnitude(offset)

		if maxDistance and distance > maxDistance then
			continue
		end

		local direction = offset.Unit
		local dot = lookVector:Dot(direction)

		if dot < 0.5 then
			continue
		end

		if distance < closestDistance then
			closestDistance = distance
			nearestProp = prop
		end
	end

	if not nearestProp then
		return {}
	end

	table.insert(propsToHit, nearestProp)

	for _, prop in self.availableProps do
		if not prop:IsA("BasePart") then
			continue
		end

		local distanceFromAnchor = vector.magnitude(prop.Position - nearestProp.Position)

		if distanceFromAnchor <= maxDistance then
			table.insert(propsToHit, prop)
		end
	end

	return propsToHit
end

function propAttackerController:pushProp(toBackhand: BasePart)
	local rootPart = self.rootPart
	local rootCFrame = rootPart.CFrame

	local lookVector = rootCFrame.LookVector
	local rightVector = rootCFrame.RightVector

	local directionToProp = (toBackhand.Position - rootPart.Position).Unit
	local sideDot = rightVector:Dot(directionToProp)
	local sideMultiplier = sideDot > 0 and 1 or -1

	local sideForce = rightVector * sideMultiplier
	local throwDirection = (lookVector + sideForce * 0.75).Unit
	toBackhand.AssemblyLinearVelocity = throwDirection * 70

	movingPropController.new(toBackhand)
end

function propAttackerController:performPush()
	local propsToBackhand = self:fetchProps(self.sharedConfig.ranges.attack)

	if #propsToBackhand > 0 then
		self.agent:SetAttribute("Attacking", true)

		self.currentTrack = self.backhandTracks[math.random(1, #self.backhandTracks)]
		self.currentTrack:Play(0, 1, 2)

		for _, prop in propsToBackhand do
			self:pushProp(prop)
		end

		self.connections.pushProps = self.currentTrack.Ended:Once(function()
			self.agent:SetAttribute("Attacking", false)
			self.controller:recordActionTime("backhandProp")
		end)
	end
end

function propAttackerController:update(_deltaTime: number)
	if self.controller:canSideAttack() then
		self:performPush()
	end
end

function propAttackerController:destroy()
	setmetatable(self, nil)
end

return propAttackerController
