--!strict

local itemRigging = {}
local types = require(script.Parent.Parent.Contracts)

local aliases = {
	["Left Arm"] = { "Left Arm", "LeftHand" },
	["Right Arm"] = { "Right Arm", "RightHand" },
}

function itemRigging.setAnchored(item: Model, anchored: boolean)
	for _, descendant in ipairs(item:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.Massless = true
			descendant.Anchored = anchored
		end
	end
end

local function findRigPart(character: Model, name: string): BasePart?
	for _, candidateName in ipairs(aliases[name] or { name }) do
		local candidate = character:FindFirstChild(candidateName)
		if candidate and candidate:IsA("BasePart") then
			return candidate
		end
	end
	return nil
end

function itemRigging.position(item: Model, character: Model, config: types.BaseConfig): boolean
	local rigging = config.rigging
	local joint = if typeof(rigging) == "table" then rigging[1] else nil
	if typeof(joint) ~= "table" or typeof(joint.part0) ~= "string" or typeof(joint.part1) ~= "string" then
		return false
	end
	local part0 = findRigPart(character, joint.part0)
	local part1 = item:FindFirstChild(joint.part1, true)
	if part0 == nil or part1 == nil or not part1:IsA("BasePart") then
		return false
	end
	local c0 = if typeof(joint.c0) == "CFrame" then joint.c0 else CFrame.identity
	local c1 = if typeof(joint.c1) == "CFrame" then joint.c1 else CFrame.identity
	local targetPart1 = part0.CFrame * c0 * c1:Inverse()
	item:PivotTo(targetPart1 * part1.CFrame:ToObjectSpace(item:GetPivot()))
	return true
end

return itemRigging
