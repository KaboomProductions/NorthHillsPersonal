local repairOption = {}
repairOption.__index = repairOption

function repairOption.new(optionContext)
	local self = setmetatable({}, repairOption)
	self.context = optionContext
	return self
end

function repairOption:destroy()
	setmetatable(self, nil)
end

return repairOption
