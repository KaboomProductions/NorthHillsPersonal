local ItemPickup = {}
ItemPickup.__index = ItemPickup

local service = nil

function ItemPickup.setService(value)
	service = value
end

function ItemPickup.new(data)
	local self = setmetatable({}, ItemPickup)
	self.instance = data.instance
	self.prompt = data.prompt
	self.promptHolder = data.promptHolder
	self.connection = self.prompt.Triggered:Connect(function(player)
		if service == nil or not self.instance:IsA("Model") then
			return
		end
		service:pickupWorldItem(player, self.instance, self.promptHolder)
	end)
	return self
end

function ItemPickup:destroy()
	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end
end

return ItemPickup
