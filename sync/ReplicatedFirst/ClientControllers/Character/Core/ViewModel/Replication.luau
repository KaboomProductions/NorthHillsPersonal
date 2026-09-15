local replicatedStorage = game:GetService("ReplicatedStorage")

local characterReplication = require(replicatedStorage.SharedUtilities.CharacterReplication)

local replication = {}

function replication.sendShoulderUpdate(
	controller,
	shoulderC0s: { leftShoulderC0: CFrame?, rightShoulderC0: CFrame? },
	forceSend: boolean?
)
	if next(shoulderC0s) == nil then
		return
	end

	controller.replication:send(characterReplication.packetKinds.shoulders, shoulderC0s, forceSend)
end

function replication.sendDefaultShoulders(controller)
	local shoulders = controller.shoulders

	replication.sendShoulderUpdate(controller, {
		rightShoulderC0 = shoulders.defaultRightC0,
		leftShoulderC0 = shoulders.defaultLeftC0,
	}, true)
end

function replication.updateShoulderReplication(
	controller,
	deltaTime: number,
	shoulderC0s: { leftShoulderC0: CFrame?, rightShoulderC0: CFrame? }?
)
	if shoulderC0s == nil or next(shoulderC0s) == nil then
		return
	end

	controller.replication:step(characterReplication.packetKinds.shoulders, deltaTime, shoulderC0s)
end

return replication
