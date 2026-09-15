local sellOption = {}
sellOption.__index = sellOption

function sellOption.new(optionContext)
	local self = setmetatable({}, sellOption)
	self.context = optionContext
	return self
end

function sellOption:destroy()
	setmetatable(self, nil)
end

return sellOption
