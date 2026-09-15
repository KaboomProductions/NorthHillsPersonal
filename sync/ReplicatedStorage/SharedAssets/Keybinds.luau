export type Action = {
	name: string,
	keyCodes: { Enum.KeyCode },
}

local function action(name: string, keyCodes: { Enum.KeyCode }): Action
	return table.freeze({ name = name, keyCodes = table.freeze(keyCodes) })
end

local keybinds = {
	sprint = action("sprint", { Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3 }),
	crouch = action("crouch", { Enum.KeyCode.LeftControl, Enum.KeyCode.C, Enum.KeyCode.ButtonB }),

	toggleInventory = action("toggleInventory", { Enum.KeyCode.I, Enum.KeyCode.ButtonY }),

	cycleHotbarNext = action("cycleHotbarNext", { Enum.KeyCode.ButtonR1 }),
	cycleHotbarPrevious = action("cycleHotbarPrevious", { Enum.KeyCode.ButtonL1 }),

	dropItem = action("dropItem", { Enum.KeyCode.Backspace }),
	throwItem = action("throwItem", { Enum.KeyCode.G }),

	togglePerspective = action("togglePerspective", { Enum.KeyCode.Q, Enum.KeyCode.ButtonR3 }),
	toggleMouseLock = action("toggleMouseLock", { Enum.KeyCode.Z }),

	sliderDrag = action("sliderDrag", { Enum.KeyCode.ButtonA }),
	sliderDecrease = action("sliderDecrease", { Enum.KeyCode.DPadLeft }),
	sliderIncrease = action("sliderIncrease", { Enum.KeyCode.DPadRight }),

	hotbarSlots = table.freeze({
		action("equipSlot1", { Enum.KeyCode.One }),
		action("equipSlot2", { Enum.KeyCode.Two }),
		action("equipSlot3", { Enum.KeyCode.Three }),
		action("equipSlot4", { Enum.KeyCode.Four }),
		action("equipSlot5", { Enum.KeyCode.Five }),
		action("equipSlot6", { Enum.KeyCode.Six }),
		action("equipSlot7", { Enum.KeyCode.Seven }),
		action("equipSlot8", { Enum.KeyCode.Eight }),
		action("equipSlot9", { Enum.KeyCode.Nine }),
		action("equipSlot10", { Enum.KeyCode.Zero }),
	}),
}

return table.freeze(keybinds)
