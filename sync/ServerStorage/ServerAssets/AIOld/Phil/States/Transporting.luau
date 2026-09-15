local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local serverStorage = game:GetService("ServerStorage")

local mathUtilities = require(replicatedStorage.SharedUtilities.MathUtils)
local baseState = require(serverStorage.ServerAssets.AI.BaseState)

local ignoreFolder = workspace.Ignore
local otherFolder = ignoreFolder.Other
local wellNodes = otherFolder.WellNodes:GetChildren()

local transportingState = baseState.extend("Transporting")

function transportingState:getNearestWellNodeToPosition(position: Vector3)
	local chosenNode = nil
	local previousDistance = math.huge

	for _, node in wellNodes do
		if not node:IsA("BasePart") then
			continue
		end

		local distanceToNode = vector.magnitude(position - node.Position)

		if distanceToNode < previousDistance then
			chosenNode = node
			previousDistance = distanceToNode
		end
	end

	return chosenNode
end

function transportingState:determineWellNode()
	if self.transportType == "fastTravelExit" then
		local nearestTarget = self.controller.targeting:getNearestTarget({
			range = 10000,
			canRaycast = false,
		})

		if nearestTarget and nearestTarget.root then
			return self:getNearestWellNodeToPosition(nearestTarget.root.Position)
		end

		return nil
	end

	return wellNodes[math.random(1, #wellNodes)]
end

function transportingState:getWellPivot(transportType: string): CFrame
	local wellNode = self:determineWellNode() or wellNodes[math.random(1, #wellNodes)]
	local angle = if math.random() <= 0.5 then 0 else 180
	local mainOffset = transportType == "exit" and 30 or 10
	local offset = math.random(-mainOffset, mainOffset)

	return wellNode.CFrame * CFrame.Angles(0, math.rad(angle + offset), 0)
end

function transportingState:enter()
	local controller = self.controller
	local rootPart = self.rootPart
	local spawningConfig = self.config.transporting
	local sharedConfig = self.config.shared

	local realTransportType = self.transportType
	self.transportType = self.transportType == "retreat" and "enter" or realTransportType

	local speedController = controller.speedController
	local walkSpeeds = sharedConfig.walkSpeeds

	local transportationTracks = self.tracks.transportation
	local chosenTrack = (self.transportType == "exit" or self.transportType == "fastTravelExit")
			and transportationTracks.exit
		or transportationTracks.enter

	local wellPivot = self:getWellPivot(self.transportType)
	local directionOffset = wellPivot.LookVector
		* ((self.transportType == "exit" or self.transportType == "fastTravelExit") and 0.65 or 0.45)

	local targetCFrame = (wellPivot + directionOffset) * spawningConfig.spawnOffset
	local hiddenCFrame = targetCFrame - Vector3.new(0, spawningConfig.hiddenDepthStuds, 0)
	targetCFrame = (self.transportType ~= "exit" and self.transportType ~= "fastTravelExit")
			and targetCFrame * CFrame.Angles(0, math.rad(180), 0)
		or targetCFrame

	self.agent:SetAttribute("Transporting", true)

	task.spawn(function()
		if self.transportType ~= "exit" and self.transportType ~= "fastTravelExit" then
			speedController:setLock("transporting", true)
			self.humanoid.WalkSpeed = walkSpeeds.run

			while task.wait(1 / 10) do
				local goal = targetCFrame.Position
				local distanceToNode = vector.magnitude(rootPart.Position - goal)

				if not getmetatable(self) or not controller then
					break
				end

				if self.transportType ~= "retreat" then
					local nearestTarget = controller
						and controller.targeting:getNearestTarget({
							range = sharedConfig.ranges.run,
							canRaycast = true,
							useTargetCache = true,
						})

					if nearestTarget ~= nil then
						controller.stateMachine:change(controller.states.Running, {
							runAndScream = true,
						})

						continue
					end
				end

				if distanceToNode <= sharedConfig.pathDistanceTolerance then
					break
				end

				pcall(
					function() --// idc anymore, i js need this to stop printing errors, i'll come back to this another time
						if getmetatable(self) and getmetatable(controller) and self.pathfinder then
							self.pathfinder:Run(targetCFrame.Position)
						end
					end
				)
			end
		end

		controller:setMidAction(true)
		rootPart.Anchored = true
		rootPart:PivotTo(
			(self.transportType == "exit" or self.transportType == "fastTravelExit") and hiddenCFrame or targetCFrame
		)

		chosenTrack:Play(0.1)

		task.delay(0.4, function()
			local riseFinished = true

			if self.transportType == "exit" or self.transportType == "fastTravelExit" then
				riseFinished = false

				task.spawn(function()
					local currentY = hiddenCFrame.Position.Y
					local targetY = targetCFrame.Position.Y

					while currentY < targetY - 0.01 do
						local deltaTime = runService.Heartbeat:Wait()
						currentY = mathUtilities.lerp(currentY, targetY, spawningConfig.riseLerpSpeed * deltaTime)

						local currentPosition = rootPart.Position
						rootPart:PivotTo(
							CFrame.new(currentPosition.X, currentY, currentPosition.Z)
								* (rootPart.CFrame - rootPart.CFrame.Position)
						)
					end

					rootPart:PivotTo(targetCFrame)
					riseFinished = true
				end)
			end

			self.connections.spawningEnded = chosenTrack:GetMarkerReachedSignal("End"):Once(function()
				chosenTrack:Stop(0.3)

				task.spawn(function()
					while not riseFinished do
						task.wait()
					end

					if self.transportType == "exit" or self.transportType == "fastTravelExit" then
						rootPart.Anchored = false
						controller:setMidAction(false)
						controller.stateMachine:change(controller.states.Wandering)
						self.agent:SetAttribute("Transporting", false)
						return
					end

					if realTransportType == "retreat" then
						controller:destroy()
						return
					end

					if self.transportType == "fastTravelEnter" then
						controller.stateMachine:change(controller.states.Transporting, {
							transportType = "fastTravelExit",
						})
					end
				end)
			end)
		end)
	end)
end

function transportingState.new(controller: any, extraInfo: { [string]: any }?)
	local self = baseState.new(transportingState, controller, extraInfo)

	local safeExtraInfo = extraInfo or {}
	self.transportType = safeExtraInfo.transportType or "exit"

	return self
end

return transportingState
