--!strict

local itemIds = require(script.Parent.Parent.Items.ItemIds)
local types = require(script.Parent.Parent.Contracts)

type ItemSnapshot = {
	parent: Instance?,
	attributes: { [string]: any },
	tags: { string },
	pivot: CFrame?,
	parts: { [BasePart]: { boolean } },
}

type Scope = {
	items: { [Instance]: ItemSnapshot },
	created: { [Instance]: boolean },
	retired: { [Instance]: boolean },
	publish: { () -> () },
	afterCommit: { () -> () },
	undo: { () -> () },
}

local mutation = {}
local scopes: { [thread]: Scope } = {}

function mutation.watch(item: Instance)
	local scope = scopes[coroutine.running()]

	if scope == nil or scope.items[item] or scope.created[item] then
		return
	end

	local parts: { [BasePart]: { boolean } } = {}

	for _, part in item:GetDescendants() do
		if part:IsA("BasePart") then
			parts[part] = { part.Anchored, part.CanCollide, part.CanQuery, part.Massless }
		end
	end

	scope.items[item] = {
		parts = parts,
		parent = item.Parent,
		attributes = item:GetAttributes(),
		tags = item:GetTags(),
		pivot = if item:IsA("Model") then item:GetPivot() else nil,
	}
end

function mutation.created(item: Instance)
	local scope = scopes[coroutine.running()]
	if scope then
		scope.created[item] = true
	end
end

function mutation.retire(item: Instance): boolean
	local scope = scopes[coroutine.running()]
	if scope == nil then
		return false
	end
	mutation.watch(item)
	scope.retired[item] = true
	return true
end

function mutation.publish(callback: () -> ())
	local scope = scopes[coroutine.running()]
	if scope then
		table.insert(scope.publish, callback)
	else
		callback()
	end
end

function mutation.afterCommit(callback: () -> ())
	local scope = scopes[coroutine.running()]
	if scope then
		table.insert(scope.afterCommit, callback)
	else
		callback()
	end
end

function mutation.onRollback(callback: () -> ())
	local scope = assert(scopes[coroutine.running()], "No inventory mutation is active")
	table.insert(scope.undo, callback)
end

local function destroyItem(item: Instance)
	itemIds.release(item)
	item:Destroy()
end

local function restoreItems(scope: Scope)
	for item in scope.created do
		destroyItem(item)
	end

	for item, snapshot in scope.items do
		for name in item:GetAttributes() do
			if snapshot.attributes[name] == nil then
				item:SetAttribute(name, nil)
			end
		end

		for name, value in snapshot.attributes do
			item:SetAttribute(name, value)
		end

		for _, tag in item:GetTags() do
			if not table.find(snapshot.tags, tag) then
				item:RemoveTag(tag)
			end
		end

		for _, tag in snapshot.tags do
			item:AddTag(tag)
		end

		for part, flags in snapshot.parts do
			part.Anchored, part.CanCollide, part.CanQuery, part.Massless = flags[1], flags[2], flags[3], flags[4]
		end

		item.Parent = snapshot.parent
		if snapshot.pivot and item:IsA("Model") then
			item:PivotTo(snapshot.pivot)
		end

		local itemId = snapshot.attributes.ItemId
		if typeof(itemId) == "string" then
			itemIds.restore(itemId)
		end
	end
end

function mutation.run(state: types.State, callback: types.TransactionCallback, restorePublication: () -> ()): ...unknown
	local slots: { [ObjectValue]: Instance? } = {}
	local originalSlots: { [Instance]: boolean } = {}
	local scope: Scope = { items = {}, created = {}, retired = {}, publish = {}, afterCommit = {}, undo = {} }
	local materials = table.clone(state.materials)
	local capacity = state.storageCapacity
	local currentSlot = state.currentSlot
	local worker = coroutine.create(function()
		scopes[coroutine.running()] = scope
		for _, folder in { state.hotbar, state.storage } do
			for _, slot in folder:GetChildren() do
				if slot:IsA("ObjectValue") then
					originalSlots[slot] = true
					slots[slot] = slot.Value
					if slot.Value then
						mutation.watch(slot.Value)
					end
				end
			end
		end

		local result: { [number]: unknown } & { n: number } = table.pack(callback())
		local response = result[1]
		if typeof(response) == "table" and (response :: any).ok == false then
			return false, result
		end

		for _, publish in scope.publish do
			publish()
		end

		return true, result
	end)

	local resumed, accepted, result = coroutine.resume(worker)
	if coroutine.status(worker) ~= "dead" then
		task.cancel(worker)
		resumed = false
		accepted = "Inventory mutation yielded; move yielding work outside withLock"
	end

	scopes[worker] = nil
	if not resumed or not accepted then
		for index = #scope.undo, 1, -1 do
			scope.undo[index]()
		end

		restoreItems(scope)
		for _, folder in { state.hotbar, state.storage } do
			for _, slot in folder:GetChildren() do
				if slot:IsA("ObjectValue") then
					if originalSlots[slot] then
						slot.Value = slots[slot]
					else
						slot:Destroy()
					end
				end
			end
		end

		table.clear(state.materials)
		for name, count in materials do
			state.materials[name] = count
		end

		state.storageCapacity = capacity
		state.currentSlot = currentSlot
		restorePublication()

		if not resumed then
			error(tostring(accepted), 0)
		end

		return table.unpack(result, 1, (result :: any).n)
	end

	for item in scope.retired do
		destroyItem(item)
	end

	for _, afterCommit in scope.afterCommit do
		local ok, problem = pcall(function()
			afterCommit()
			return nil
		end)

		if not ok then
			warn("[Inventory] Post-commit cleanup failed:", problem)
		end
	end

	return table.unpack(result, 1, (result :: any).n)
end

return mutation
