local replicatedStorage = game:GetService("ReplicatedStorage")

local sharedClasses = replicatedStorage.SharedClasses

local inputHelpers = {}
inputHelpers.mobileButtonHolder = require(sharedClasses.MobileButton)

function inputHelpers.wireMobileButton(bind, guiButton: ImageButton, name: string, defaultVisible: boolean?)
	if defaultVisible == nil then
		defaultVisible = true
	end

	if name then
		inputHelpers.mobileButtonHolder.register(name, guiButton, defaultVisible)
	end

	guiButton.MouseButton1Down:Connect(function()
		bind:Fire(true, true)
	end)

	guiButton.MouseButton1Up:Connect(function()
		bind:Fire(false, false)
	end)
end

function inputHelpers.attachAllKeysToInput(inputObject: any, keyCodeData: { Enum.KeyCode })
	for _, keyCode in ipairs(keyCodeData) do
		inputObject:AddBind(keyCode)
	end
end

return inputHelpers
