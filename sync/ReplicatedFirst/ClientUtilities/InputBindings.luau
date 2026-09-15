local replicatedStorage = game:GetService("ReplicatedStorage")
local userInputService = game:GetService("UserInputService")

local inputActionService = require(replicatedStorage.SharedUtilities.InputActionService)
local mobileButtons = require(replicatedStorage.SharedClasses.MobileButton)

local inputBindings = {}

export type Binding = inputActionService.BindingObject
export type Action = {
	name: string,
	keyCodes: { Enum.KeyCode },
}
export type Connection = { Disconnect: (self: Connection) -> () }
export type Options = {
	priority: number?,
	sink: boolean?,
	button: GuiButton?,
	mobileName: string?,
	isVisible: boolean?,
}

local connectionsByBinding: { [Binding]: { Connection } } = {}

function inputBindings.create(definition: Action, options: Options?): Binding
	local previousBinding = inputActionService.get(definition.name)
	if previousBinding then
		previousBinding:Destroy()
	end

	local binding = inputActionService.new(definition.name, Enum.InputActionType.Bool)
	local connections: { Connection } = {}
	connectionsByBinding[binding] = connections

	local destroyBinding = binding.Destroy
	local isDestroyed = false

	binding.Destroy = function(self: Binding): boolean
		if isDestroyed then
			return false
		end
		isDestroyed = true
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		connectionsByBinding[self] = nil
		if options and options.mobileName then
			mobileButtons.unRegister(options.mobileName)
		end
		return destroyBinding(self)
	end

	for _, keyCode in definition.keyCodes do
		binding:AddBind(keyCode)
	end

	if options then
		if options.priority ~= nil then
			binding:SetPriority(options.priority)
		end

		if options.sink ~= nil then
			binding:SetSink(options.sink)
		end

		if options.button then
			binding:SetUIButton(options.button)
			if options.mobileName then
				mobileButtons.register(options.mobileName, options.button, options.isVisible)
			end
		end
	end

	return binding
end

function inputBindings.isTextFocused(): boolean
	return userInputService:GetFocusedTextBox() ~= nil
end

function inputBindings.connect(binding: Binding, callback: (boolean, boolean) -> ()): Connection
	local isPressed = false
	local isConnected = true
	local function release()
		if not isPressed then
			return
		end
		isPressed = false
		callback(false, false)
	end

	local activation = binding.Activated:Connect(function(active, pressed)
		if not pressed then
			release()
			return
		end

		if isPressed or inputBindings.isTextFocused() then
			return
		end

		isPressed = true
		callback(active == true, true)
	end)

	local textFocus = userInputService.TextBoxFocused:Connect(release)
	local windowFocus = userInputService.WindowFocusReleased:Connect(release)

	local connection: Connection = {
		Disconnect = function()
			if not isConnected then
				return
			end

			isConnected = false
			activation:Disconnect()
			textFocus:Disconnect()
			windowFocus:Disconnect()
			release()
		end,
	}

	local connections = connectionsByBinding[binding]
	table.insert(connections, connection)
	return connection
end

return inputBindings
