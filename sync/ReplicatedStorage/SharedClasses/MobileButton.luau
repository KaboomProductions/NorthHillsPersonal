local replicatedFirst = game:GetService("ReplicatedFirst")
local userInputService = game:GetService("UserInputService")

local clientData = require(replicatedFirst.ClientData)
local mobileGuiHolder = {}

local registry: {
	[string]: {
		button: GuiObject,
		userVisible: boolean
	} 
} = {}

function mobileGuiHolder.refreshSingle(name: string)
	local entry = registry[name]
	
	if entry then
		entry.button.Visible = clientData.isMobile() and entry.userVisible
	end
end

function mobileGuiHolder.refreshAll()
	for name in registry do
		mobileGuiHolder.refreshSingle(name)
	end
end

function mobileGuiHolder.register(name: string, button: GuiObject, defaultVisible: boolean?)
	registry[name] = {
		button = button,
		userVisible = if defaultVisible == nil then true else defaultVisible
	}

	mobileGuiHolder.refreshSingle(name)
end

function mobileGuiHolder.unRegister(name: string)
	registry[name] = nil
end

function mobileGuiHolder.setVisible(name: string, visible: boolean)
	local entry = registry[name]

	if entry then
		entry.userVisible = visible
		mobileGuiHolder.refreshSingle(name)
	end
end

function mobileGuiHolder.isVisible(name: string): boolean
	local entry = registry[name]
	return entry ~= nil and entry.userVisible
end

userInputService.LastInputTypeChanged:Connect(function()
	mobileGuiHolder.refreshAll()
end)

return mobileGuiHolder