local replicatedStorage = game:GetService("ReplicatedStorage")
local userInputService = game:GetService("UserInputService")

local keybinds = require(replicatedStorage.SharedAssets.Keybinds)
local keybindDisplay = {}

function keybindDisplay.getHotbarText(index: number): string
	local definition = keybinds.hotbarSlots[index]
	local keyCode = definition and definition.keyCodes[1]
	if keyCode == nil then
		return ""
	end

	local keyText = userInputService:GetStringForKeyCode(keyCode)
	return if keyText ~= "" then keyText else keyCode.Name
end

return keybindDisplay
