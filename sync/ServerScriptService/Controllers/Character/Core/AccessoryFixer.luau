local players = game:GetService("Players")

local accessoryFixerController = {}
accessoryFixerController.__index = accessoryFixerController
accessoryFixerController.__vars = {
	accessorySetupDelaySeconds = 1,
}

local layeredClothingTypes = {
	[Enum.AccessoryType.Shirt] = true,
	[Enum.AccessoryType.Pants] = true,
	[Enum.AccessoryType.Jacket] = true,
	[Enum.AccessoryType.Sweater] = true,
	[Enum.AccessoryType.TShirt] = true,
	[Enum.AccessoryType.Shorts] = true,
	[Enum.AccessoryType.LeftShoe] = true,
	[Enum.AccessoryType.RightShoe] = true,
	[Enum.AccessoryType.DressSkirt] = true,
}

local function isLayeredClothing(accessory: Accessory): boolean
	local accessoryTypeValue = accessory:FindFirstChild("AccessoryType")
	if not accessoryTypeValue then
		return false
	end

	return layeredClothingTypes[accessoryTypeValue.Value] == true
end

function accessoryFixerController:fixCharacterAccessories(character: Model)
	local player = self.player
	if player == nil then
		return
	end

	local fixerRigTemplate = script:FindFirstChild("FixerRig")
	if fixerRigTemplate == nil then
		return
	end

	local fixerRig = fixerRigTemplate:Clone()
	fixerRig.Parent = script

	local rigHumanoid = fixerRig:FindFirstChildOfClass("Humanoid")
	local humanoidDescription = players:GetHumanoidDescriptionFromUserId(player.UserId)

	if rigHumanoid then
		rigHumanoid:ApplyDescription(humanoidDescription)

		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Accessory") then
				child:Destroy()
			end
		end

		for _, accessory in ipairs(fixerRig:GetChildren()) do
			if not accessory:IsA("Accessory") then
				continue
			end

			if isLayeredClothing(accessory) then
				continue
			end

			for _, descendant in ipairs(accessory:GetDescendants()) do
				if descendant:IsA("MeshPart") or descendant:IsA("Part") then
					descendant.AudioCanCollide = false
					descendant.CastShadow = false
				end
			end

			accessory.Parent = character
		end
	end

	fixerRig:Destroy()
end

function accessoryFixerController:init()
	local stateValues = self.__vars
	local accessorySetupDelaySeconds = stateValues.accessorySetupDelaySeconds

	task.delay(accessorySetupDelaySeconds, function()
		if self.player == nil or self.character == nil then
			return
		end

		self:fixCharacterAccessories(self.character)
	end)
end

function accessoryFixerController.new(player: Player, character: Model)
	local self = setmetatable({}, accessoryFixerController)

	self.player = player
	self.character = character
	self.connections = {}
	self.__vars = table.clone(accessoryFixerController.__vars)

	task.defer(self.init, self)

	return self
end

function accessoryFixerController:destroy()
	local connections = self.connections

	for _, connection in pairs(connections) do
		connection:Disconnect()
	end

	table.clear(connections)
	table.clear(self)
	setmetatable(self, nil)
end

return accessoryFixerController
