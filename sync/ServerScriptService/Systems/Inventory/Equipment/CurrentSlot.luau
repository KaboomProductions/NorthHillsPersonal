--!strict

local currentSlot = {}
local types = require(script.Parent.Parent.Contracts)

type State = types.State

function currentSlot.set(state: State, slotNumber: number): ()
	state.currentSlot = slotNumber
	if state.replica then
		state.replica:setCurrentSlot(slotNumber)
	end
end

function currentSlot.clear(state: State): ()
	state.currentSlot = nil
	if state.replica then
		state.replica:setCurrentSlot(nil)
	end
end

return currentSlot
