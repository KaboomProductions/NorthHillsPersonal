local autoRig = {}

local rigPartAliases = {
	["Left Arm"] = { "Left Arm", "LeftHand" },
	["Right Arm"] = { "Right Arm", "RightHand" },
}

local function matchesRigPart(object: Instance, configuredName: string): boolean
	local aliases = rigPartAliases[configuredName]
	if aliases == nil then
		return object.Name == configuredName
	end
	for _, name in ipairs(aliases) do
		if object.Name == name then
			return true
		end
	end
	return false
end

function autoRig.createMotor(info: {
	name: string,
	c0: CFrame,
	c1: CFrame,
	part0: BasePart,
	part1: BasePart,
	isWeld: boolean,
})
	local newMotor = info.isWeld and Instance.new("Weld") or Instance.new("Motor6D")
	newMotor.Name = info.name
	newMotor.C0 = info.c0
	newMotor.C1 = info.c1
	newMotor.Part0 = info.part0
	newMotor.Part1 = info.part1
	newMotor.Parent = info.part0
end

export type RigJointConfig = {
	part0: string,
	part1: string,
	c0: CFrame?,
	c1: CFrame?,
	isWeld: boolean?,
}

export type RigConfig = { RigJointConfig } & { isWeld: boolean? }

function autoRig.rig(info: { tool: Tool, character: Model, config: RigConfig })
	local tool: Tool = info.tool
	local character: Model = info.character

	local rigObjects = {}
	local config: RigConfig = info.config

	for _, part in ipairs(character:GetChildren()) do
		if not part:IsA("BasePart") then
			continue
		end

		table.insert(rigObjects, part)
	end

	for _, part in ipairs(tool:GetChildren()) do
		if not part:IsA("BasePart") then
			continue
		end

		table.insert(rigObjects, part)
	end

	for _, data in ipairs(config) do
		local part0Name: string = data.part0
		local part1Name: string = data.part1

		local toReturn = {
			part0 = nil,
			part1 = nil,
			c0 = data.c0 or CFrame.identity,
			c1 = data.c1 or CFrame.identity,
			name = tool.Name,
			isWeld = data.isWeld == true or config.isWeld == true,
		}

		for _, object: Instance in ipairs(rigObjects) do
			if matchesRigPart(object, part0Name) then
				toReturn.part0 = object
			end

			if object.Name == part1Name then
				toReturn.part1 = object
			end
		end

		assert(toReturn.part0, string.format("Missing rig part %s", part0Name))
		assert(toReturn.part1, string.format("Missing tool part %s", part1Name))
		autoRig.createMotor(toReturn)
	end
end

return autoRig
