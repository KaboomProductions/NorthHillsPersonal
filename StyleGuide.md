# North Hills Style Guide

This document defines the preferred coding style for the North Hills codebase.

The goal is readable, maintainable, self-documenting code. Good naming and clean structure should do most of the explanatory work, so comments should almost never be needed.

This guide contains both hard rules and preferred direction. Hard rules should be followed across the codebase, including legacy modules when they are touched. Preferred direction explains how to resolve cases where more than one acceptable pattern exists.

## Core Principles

### Prioritize Clarity

- Prefer clarity over brevity.
- Prefer explicit names over clever shorthand.
- Prefer code that explains itself through naming and structure.
- Prefer small focused functions and modules over large mixed-responsibility ones.

### Write Code That Scales

- Name things for future readers, not just the current task.
- Keep modules easy to expand without rewriting their structure.
- Put code in the runtime layer that actually owns it.
- Type public boundaries so systems stay safer as the project grows.

### Optimize for Maintainability

- A function should do one thing.
- A module should own one area of responsibility.
- Shared code should be truly shared-safe, not just convenient to import.
- If a comment is explaining basic behavior, improve the code first.
- If you feel like you need comments throughout a function, split or rename the code until the comments are unnecessary.

## Quick Rules

### Must

- use `lowerCamelCase` for variables, fields, parameters, and functions
- use full descriptive words instead of shorthand
- use `PascalCase` for module names and types
- use `--//` for comments
- require utility modules directly
- use `:GetChildren()` for expandable module loading
- type function parameters and important module boundaries
- use `module.__vars` in `__index`-based OOP modules when the module has meaningful default runtime state
- place `module.__vars` directly under `module.__index` with no blank line between them
- cache repeated `self` fields into locals inside functions

### Avoid

- single-letter variables except `_` for intentionally unused values
- vague names like `thing`, `stuff`, `data`, `info`, `value`, `object`
- `unpackUtilities()` or parent-module utility unpacking
- giant modules that mix unrelated systems
- giant functions that validate, mutate, animate, and communicate all at once
- plain `--` comments
- regular explanatory comments when clearer naming or structure would remove the need

## Naming

### Variables, Fields, Parameters, and Functions

Use `lowerCamelCase` with full descriptive words.

Good:

- `currentState`
- `moveDirection`
- `targetSprintSpeed`
- `lerpedHealthAverage`
- `deltaTime`
- `playerCharacter`
- `footstepSound`
- `pathfindingResult`

Avoid:

- `x`, `i`, `d`, `v`
- `dt`, `spd`, `dir`, `char`, `anim`
- `thing`, `stuff`, `data`, `info`, `value`, `object`

Prefer:

- `movementDirection` over `dir`
- `currentHumanoidState` over `state`
- `animationTrack` over `anim`
- `playerSettings` over `settings` when multiple settings tables are in scope

### Allowed Abbreviations

Avoid abbreviations by default.

Only these abbreviations are allowed when they remain readable:

- `min`
- `max`
- `stat`
- `ui`
- `npc`
- `ai`
- `id`

Do not add new abbreviations to this list ad hoc. If an abbreviation makes code less readable, spell it out.

### Boolean Naming

Boolean names should read naturally in conditionals.

Prefer prefixes like:

- `is`
- `has`
- `can`
- `should`
- `was`
- `did`

Good:

- `isSprinting`
- `hasLineOfSight`
- `canInteract`
- `shouldPlayAudio`
- `wasInterrupted`

Avoid:

- `sprinting`
- `lineOfSight`
- `audio`

### Callback and Helper Naming

Use names that reflect responsibility.

- `on...` for event handlers
- `handle...` for branching request/response logic
- `update...` for state refresh logic
- `calculate...` for computed values
- `get...` for returned lookups
- `create...` for object/tween/instance creation
- `should...` for decision helpers

Good:

- `onFootstepEvent`
- `onCharacterAdded`
- `handleShopChoice`
- `updateMovementState`
- `calculateSprintSpeed`
- `getNearestTarget`
- `createDoorTween`

Avoid:

- `run`
- `doThing`
- `processData`
- `handler`
- `callback`

### Collections and Tables

Name collections after what they contain.

Good:

- `activePlayers`
- `footstepSounds`
- `targetCharacters`
- `shopCategories`
- `playerStatesByUserId`

Avoid:

- `list`
- `array`
- `table`
- `values`

If a table is keyed, reflect that when it helps:

- `playersByUserId`
- `statesByName`
- `itemsByType`

### Temporary Variables

Temporary does not mean vague.

Good:

- `nextState`
- `previousHealth`
- `currentTarget`
- `newMotor`
- `raycastResult`

Avoid:

- `temp`
- `tmp`
- `newValue`
- `result` when a more specific name is possible
- `vars`
- `config`
- `info`
- `data`
- `value`
- `object`

### Numeric Names and Units

If a number has a meaningful unit, include the unit in the name.

Good:

- `deltaTime`
- `distanceStuds`
- `durationSeconds`
- `angleRadians`
- `speedStudsPerSecond`
- `chancePercent`

Avoid:

- `time`
- `distance`
- `speed`
- `angle`

unless the unit is already obvious in a very small local scope.

### Loop Variables

Loop variables should describe what is being iterated.

Good:

- `for _, player in ipairs(players) do`
- `for _, moduleScript in ipairs(moduleScripts) do`
- `for stateName, stateModule in pairs(statesByName) do`

Avoid:

- `for i, v in ipairs(players) do`
- `for _, obj in ipairs(objects) do`

The only one-letter exception is `_` for intentionally unused values.
Do not use one-letter loop names like `i`, `j`, or `v`, including numeric loops.

### Naming by Scope

Do not repeat context that the surrounding scope already provides.

Inside a stamina controller:

- use `currentState`
- not `staminaCurrentState`

Inside an AI module:

- use `currentTarget`
- not `aiCurrentTarget`

Add more context only when it prevents ambiguity.

### Module, Type, and Service Names

Use `PascalCase` for:

- `ModuleScript` names
- exported type names when mirrored from a concept/module
- class-like tables

Examples:

- `Animation`
- `Math`
- `AudioUtils`
- `AI`
- `MovementState`
- `FootstepController`

Use `lowerCamelCase` for local references to modules and services.

Good:

- `local animationUtilities = require(...)`
- `local aiController = {}`
- `local replicatedStorage = game:GetService("ReplicatedStorage")`
- `local serverStorage = game:GetService("ServerStorage")`
- `local userInputService = game:GetService("UserInputService")`

Approved alias examples for shared readability:

- `replicatedStorage`
- `serverStorage`
- `sharedUtilities`
- `clientRuntime`
- `players`

Avoid:

- `rs`
- `ss`
- `sss`
- `uis`
- `cp`

### Constants and Immutable Values

Use descriptive `lowerCamelCase` even for values that do not change.

Good:

- `defaultSprintSpeed`
- `maximumStamina`
- `minimumPitch`

Avoid `SCREAMING_SNAKE_CASE` unless an external API or format requires it.

## Type Annotations

The codebase should move toward stronger Luau typing over time.

The goal is not to type every single variable. The goal is to type the places where types improve safety, readability, and maintainability.

### Prefer Boundary Typing

Strongly prefer type annotations on:

- function parameters
- meaningful return values
- exported types
- constructor input tables
- public module APIs
- shared data structures with stable shapes

Good:

- `function updateStamina(deltaTime: number, movementDirection: Vector3)`
- `function getNearestTarget(originPosition: Vector3): Model?`
- `export type interactionContext = { player: Player, prompt: ProximityPrompt }`

### Do Not Over-Annotate Locals

Do not annotate every local just because it is possible.

Avoid noise like:

- `local currentHealth: number = humanoid.Health`
- `local playerName: string = player.Name`

Prefer inference for:

- short-lived locals
- obvious primitive assignments
- values whose types are already clear from the API

### Prefer Named Table Types

If a table has a known structure, name that structure.

Prefer:

- `export type pathingOptions = { agentRadius: number, agentHeight: number }`
- `function createMotor(motorInfo: motorInfo)`
- `local itemConfig = require(configModule)`

Avoid:

- `config: {}`
- `info: {}`
- `data: any`

unless the shape is genuinely dynamic or not known yet.

### Use `any` Sparingly

`any` is a last resort, not a default.

Reasonable uses:

- temporary interop with legacy code
- hard-to-express engine interactions
- transitional code during refactors

If `any` is used, narrow it as quickly as possible.

### Practical Typing Rule

When writing a new function:

- type the parameters
- type the return if it is non-obvious, optional, or table-shaped
- do not feel forced to type every local inside the function

When writing a new module:

- type the public API
- type reusable table shapes
- let obvious implementation details infer naturally

## Writing Modules

There are two valid module styles in this codebase:

- plain utility modules
- stateful OOP modules

Do not mix the two patterns unless there is a strong reason.

### Use a Utility Module When

Use a plain module table for stateless helpers.

A utility module should:

- return a table of functions
- avoid `.new()`
- avoid owning mutable per-instance state
- avoid connections and long-lived runtime behavior
- avoid side effects at require time

Good fits:

- `Math`
- `Animation`
- `AudioUtils`

### Use an OOP Module When

Use a stateful OOP module when the module owns runtime state over time.

Good fits:

- controllers
- managers
- handlers
- stateful gameplay objects
- modules that own connections, child controllers, or instance references

### Standard OOP Lifecycle

Stateful modules should follow this pattern:

- `.new()`
- `:preload()`
- `:init()`
- `:destroy()`

This is the preferred lifecycle for runtime modules in the project.

If a touched module already uses the OOP pattern, bring it into this lifecycle consistently instead of preserving older partial patterns.

### What Each Lifecycle Method Should Do

#### `.new()`

`.new()` should:

- create `self` with `setmetatable`
- assign required references
- initialize owned tables like `self.connections` or `self.controllers`
- clone `module.__vars` into `self.__vars` when `module.__vars` exists
- schedule startup with `task.defer()` by default when startup may yield
- return `self`

`.new()` should not:

- perform long waits inline
- connect a large number of signals inline
- start gameplay loops inline
- hide expensive startup work that belongs in `:preload()` or `:init()`

#### `:preload()`

Use `:preload()` for setup work:

- caching descendants or references
- cloning required components
- preparing remotes, folders, and tables
- creating helper instances
- loading animations

If a module has nothing to preload, omit `:preload()` instead of leaving it empty.

#### `:init()`

Use `:init()` for activation work:

- calling `:preload()`
- connecting signals
- starting loops
- reacting to replicated state
- creating child controllers
- beginning active behavior

If startup requires waits, those usually belong here, not in `.new()`.

#### `:destroy()`

`:destroy()` must fully clean up what the module owns.

It should:

- disconnect owned connections
- cancel tweens and stop loops where possible
- destroy helper instances created by the module when appropriate
- destroy owned child controllers
- clear runtime tables and references

When the module fully owns its instance state and no external code should keep using the object after teardown, prefer aggressive teardown such as clearing owned tables, clearing `self`, and removing the metatable.

`destroy()` should be safe even if startup only partially completed.

### Use `module.__vars`

`module.__vars` belongs to `__index`-based OOP modules that have meaningful default runtime state or tunable values.

If a module does not use `__index`, or it has no meaningful default runtime state to centralize, `module.__vars` is not required.

Use `module.__vars` for:

- default state values
- tunable numeric values
- default booleans
- current selection or mode fields
- values that should be easy to scan in one place

Keep `module.__vars` directly under `module.__index` with no blank line between them so the two declarations read as a single header block.

Example:

```lua
local staminaController = {}
staminaController.__index = staminaController
staminaController.__vars = {
	currentState = "Idle",
	targetSprintSpeed = 18,
	recoveryDelaySeconds = 1.25,
	isRecovering = false,
}
```

In `.new()`, create a per-instance copy:

```lua
self.__vars = table.clone(staminaController.__vars)
```

Do not mutate `module.__vars` directly at runtime. It is the template, not the live instance state.

Private underscore fields like `self._isEquipped` are still acceptable for transient or derived state that does not belong in the default-state template.

### Cache Repeated `self` Access

Do not index through `self` over and over when the same fields are used repeatedly.

Repeated `self.someField` access is noisy and harder to read. Cache frequently used fields into locals near the top of the function.

Prefer:

```lua
function staminaController:updateState(deltaTime: number)
	local stateValues = self.__vars
	local humanoid = self.humanoid
	local staminaBar = self.staminaBar

	if not humanoid or not staminaBar then
		return
	end

	local currentState = stateValues.currentState
	local targetSprintSpeed = stateValues.targetSprintSpeed

	--// Use the locals from here.
end
```

Avoid:

```lua
function staminaController:updateState(deltaTime: number)
	if not self.humanoid or not self.staminaBar then
		return
	end

	local currentState = self.__vars.currentState
	local targetSprintSpeed = self.__vars.targetSprintSpeed

	--// self.humanoid, self.staminaBar, self.__vars, self.__vars...
end
```

If a field is accessed once, `self.field` is fine. If it is used repeatedly, cache it.

Do not treat `vars` as a general shorthand exception. If you cache `self.__vars`, use a fuller local name such as `stateValues`.

### OOP Module Template

```lua
local replicatedStorage = game:GetService("ReplicatedStorage")

local sharedUtilities = replicatedStorage.SharedUtilities
local mathUtilities = require(sharedUtilities.Math)

local exampleController = {}
exampleController.__index = exampleController
exampleController.__vars = {
	isOpen = false,
	openAngleRadians = math.rad(90),
}

export type exampleControllerInfo = {
	instance: Instance,
}

function exampleController:preload()
	local instance = self.instance

	--// Cache references and prepare helper instances here.
	self.door = instance:FindFirstChild("Door")
end

function exampleController:init()
	local stateValues = self.__vars

	self:preload()

	if stateValues.isOpen then
		return
	end

	--// Connect signals and begin active behavior here.
end

function exampleController.new(controllerInfo: exampleControllerInfo)
	local self = setmetatable({}, exampleController)

	self.instance = controllerInfo.instance
	self.connections = {}
	self.controllers = {}
	self.__vars = table.clone(exampleController.__vars)

	task.defer(self.init, self)

	return self
end

function exampleController:destroy()
	local connections = self.connections
	local controllers = self.controllers

	for _, connection in pairs(connections) do
		connection:Disconnect()
	end

	table.clear(connections)
	table.clear(controllers)
	table.clear(self)
	setmetatable(self, nil)
end

return exampleController
```

### Utility Module Example

```lua
local mathUtilities = {}

function mathUtilities.planarDistance(positionA: Vector3, positionB: Vector3): number
	local deltaX = positionA.X - positionB.X
	local deltaZ = positionA.Z - positionB.Z

	return math.sqrt(deltaX * deltaX + deltaZ * deltaZ)
end

function mathUtilities.remapClamped(
	value: number,
	inputMinimum: number,
	inputMaximum: number,
	outputMinimum: number,
	outputMaximum: number
): number
	if inputMaximum == inputMinimum then
		return outputMinimum
	end

	local normalizedAlpha = (value - inputMinimum) / (inputMaximum - inputMinimum)
	local clampedAlpha = math.clamp(normalizedAlpha, 0, 1)

	return outputMinimum + (outputMaximum - outputMinimum) * clampedAlpha
end

return mathUtilities
```

### OOP Module Example

```lua
local tweenService = game:GetService("TweenService")

local doorController = {}
doorController.__index = doorController
doorController.__vars = {
	isOpen = false,
	openDurationSeconds = 0.35,
	openAngleRadians = math.rad(90),
}

export type doorControllerInfo = {
	instance: Model,
	prompt: ProximityPrompt,
}

function doorController:preload()
	local instance = self.instance
	local stateValues = self.__vars

	self.door = instance:FindFirstChild("Door")
	self.closedCFrame = self.door and self.door.CFrame
	self.openCFrame = self.closedCFrame and self.closedCFrame * CFrame.Angles(0, stateValues.openAngleRadians, 0)
end

function doorController:createDoorTween(targetCFrame: CFrame): Tween?
	local door = self.door
	local stateValues = self.__vars

	if not door then
		return nil
	end

	return tweenService:Create(door, TweenInfo.new(stateValues.openDurationSeconds), { CFrame = targetCFrame })
end

function doorController:openDoor()
	local stateValues = self.__vars
	local openCFrame = self.openCFrame

	if not openCFrame then
		return
	end

	stateValues.isOpen = true
	self.doorTween = self:createDoorTween(openCFrame)

	if self.doorTween then
		self.doorTween:Play()
	end
end

function doorController:closeDoor()
	local stateValues = self.__vars
	local closedCFrame = self.closedCFrame

	if not closedCFrame then
		return
	end

	stateValues.isOpen = false
	self.doorTween = self:createDoorTween(closedCFrame)

	if self.doorTween then
		self.doorTween:Play()
	end
end

function doorController:onPromptTriggered()
	local stateValues = self.__vars

	if stateValues.isOpen then
		self:closeDoor()
		return
	end

	self:openDoor()
end

function doorController:init()
	local prompt = self.prompt

	self:preload()

	self.connections.promptTriggered = prompt.Triggered:Connect(function()
		self:onPromptTriggered()
	end)
end

function doorController.new(controllerInfo: doorControllerInfo)
	local self = setmetatable({}, doorController)

	self.instance = controllerInfo.instance
	self.prompt = controllerInfo.prompt
	self.connections = {}
	self.__vars = table.clone(doorController.__vars)

	task.defer(self.init, self)

	return self
end

function doorController:destroy()
	local connections = self.connections
	local doorTween = self.doorTween

	if doorTween then
		doorTween:Cancel()
		self.doorTween = nil
	end

	for _, connection in pairs(connections) do
		connection:Disconnect()
	end

	table.clear(connections)
	table.clear(self)
	setmetatable(self, nil)
end

return doorController
```

### Preferred File Order for OOP Modules

Use this order when possible:

1. services and requires
2. constants
3. module table and `__index`
4. `module.__vars`
5. exported types
6. local helper functions
7. instance helper methods
8. `:preload()`
9. `:init()`
10. `.new()`
11. `:destroy()`
12. `return module`

### Construction and Ownership Rules

- name constructor input types descriptively using the module or domain, such as `doorControllerInfo`
- put required references into `self` during `.new()`
- clone `module.__vars` into `self.__vars` when `module.__vars` exists
- initialize owned state explicitly
- track every connection the module creates
- destroy every child controller the module owns
- do not rely on startup order when a nil guard or delayed init is safer

### Require-Time Rules

At require time, modules may:

- get services
- require dependencies
- define constants
- define local helper functions
- define the module table and types

At require time, modules should not:

- connect events
- mutate the world
- start loops
- wait for gameplay state
- create instance-specific runtime state

Requiring a module should be safe and predictable.

### When Lifecycle Methods Can Be Omitted

- no `.new()` for plain utility modules
- no `:preload()` if there is nothing to preload
- no `:destroy()` only if the module truly owns no runtime resources

For stateful controllers, the lifecycle should still be followed consistently.

## Module Placement

Put modules in the folder that matches who owns the behavior and where it is allowed to run.

### `ReplicatedStorage/SharedUtilities`

Use `SharedUtilities` for runtime-neutral helpers that can run unchanged on both client and server.

Good fits:

- math helpers
- animation helpers with no client-only or server-only assumptions
- table helpers
- validation helpers
- formatting helpers

Do not put a module here just because multiple places need it. It belongs here only if it is truly shared-safe.

### `ReplicatedStorage/SharedAssets`

Use `SharedAssets` for replicated data, reusable modules, and shared assets that both client and server may access.

Good fits:

- `Attributes`
- shared dictionaries
- shared classes
- shared config modules
- replicated visual and audio assets

This folder is for shared content, not client controllers or server authority logic.

### `ServerStorage/ServerUtilities`

Use `ServerUtilities` for server-only helpers.

Good fits:

- server audio helpers
- rigging helpers
- pathfinding helpers
- NPC or combat utility helpers
- helpers that create or mutate server-only instances

If a utility touches `ServerStorage`, server-only instances, or server authority state, it belongs here.

### `ServerStorage/ServerAssets`

Use `ServerAssets` for server-owned content and class-like modules that should not replicate directly.

Good fits:

- AI classes
- server prefabs
- NPC server-side state modules
- server-only assets and runtime classes

### Client Runtime Folders

Use client runtime folders for local control and presentation.

Good fits:

- camera controllers
- UI controllers
- character effects
- local animation and viewmodel logic
- local interaction presentation

### Server Runtime Folders

Use server runtime folders like `ServerScriptService` for live game systems.

Good fits:

- events
- gameplay systems
- round-cycle logic
- interactable orchestration
- server item handling

### Placement Rule

Put the module as close as possible to the runtime that owns it.

- shared only when it is truly shared
- server only when the server owns it
- client only when it is presentation or local control

Do not put modules into shared folders just to make imports convenient.

## Single Responsibility

### Modules Should Handle One Area

A module should own one clear area of responsibility.

Good module boundaries:

- `Footsteps` handles footsteps
- `BreathingStates` handles breathing audio state
- `ViewModel` handles first-person viewmodel behavior
- `RoundCycle` handles round timing and state transitions

Bad module boundaries:

- one module that handles footsteps, stamina audio, and camera shake
- one shop module that owns dialogue transport, UI animation, and item purchase validation

If a module name starts wanting `and`, it is probably doing too much.

Bad examples:

- `InventoryAndShop`
- `MovementAndAnimation`
- `DialogueAndCamera`

### Functions Should Do One Thing

A function should do one thing at one level of abstraction.

Good:

- `getNearestTarget()`
- `updateSprintState()`
- `playFootstepSound()`
- `createDoorTween()`

Bad:

- a function that finds a target, rotates the character, plays audio, and updates UI
- a function that validates input, mutates state, plays effects, and sends remotes all at once

### Split Functions When

Split a function into helpers when:

- the function name becomes vague
- you feel pressure to add comments to explain normal flow
- the function mixes validation, state updates, and effects
- the function handles unrelated branches
- the function becomes hard to scan on one screen
- the function repeats the same lookup or nil-guard patterns

Prefer:

```lua
function staminaController:updateState(deltaTime: number)
	local movementState = self:getMovementState()
	local staminaChange = self:calculateStaminaChange(movementState, deltaTime)

	self:applyStaminaChange(staminaChange)
	self:updateEffects()
end
```

Over:

```lua
function staminaController:updateState(deltaTime: number)
	--// Figures out movement, changes stamina, clamps values, updates UI,
	--// updates audio, and handles sprint transitions all in one place.
end
```

### Split Modules When

Split a module when:

- one file owns multiple unrelated systems
- different sections require very different dependencies
- one part is reusable but another is not
- the module has multiple reasons to change
- the module is growing separate internal state buckets

Examples:

- split `Shop` into `Dialogue`, `Animator`, `Helpers`, and option-specific modules
- split AI into sensing, pathing, combat, and state modules
- split a large character system into movement, effects, stats, and items

### Prefer Small Helper Functions

Use named helper functions to make the module read like a sequence of clear steps.

Prefer:

```lua
function aiController:init()
	self:preload()
	self:cacheTargets()
	self:connectRemotes()
	self:startBehaviorLoop()
end
```

Over:

```lua
function aiController:init()
	--// One long method that clones components, finds descendants,
	--// connects remotes, starts loops, and sets runtime state inline.
end
```

The helper names should tell the story of the module.

## Imports and Access Patterns

- require utility modules directly where they are used
- intermediate folder aliases like `sharedUtilities` are fine when they improve readability
- do not access utility functions by unpacking them from a parent module
- use `:GetChildren()` for expandable module loading patterns
- keep shared-safe utilities in `SharedUtilities`
- keep server-only utilities in `ServerUtilities`

## Comments

Comments should almost never be used. Only add a comment when the code would otherwise look incorrect or surprising to a future reader.

- always use `--//`
- never use plain `--`
- do not add comments for normal control flow or obvious operations

Good uses of comments:

- non-obvious engine workarounds
- behavior that looks wrong but is intentionally required
- temporary compatibility logic with a clear removal condition

Example:

- `--// Doing this every frame since Roblox resets it.`

Avoid comments like:

- `--// set the value`
- `--// loop through the players`
- `--// create a new sound`

If a comment only compensates for weak naming, improve the code instead.

## Readability Best Practices

Never Nesting convention:

- always prefer early returns whenever possible
- exit invalid or edge states first, then keep the main path flat

- prefer early returns over deep nesting
- prefer small focused functions over large multi-purpose ones
- prefer stable naming across similar systems
- group related local caches together near the top of a function
- keep lifecycle methods easy to scan
- write code so the next reader can understand it quickly

Consistent naming patterns help:

- `currentState`, `targetState`, `previousState`
- `currentHealth`, `targetHealth`, `maximumHealth`
- `startTime`, `elapsedTime`, `deltaTime`

## Final Litmus Test

Before finishing a function or module, ask:

- is the name fully descriptive
- does it do one thing
- is the runtime ownership correct
- are the important boundaries typed
- would this still be readable in six months
- does this need a comment because the code is unclear

If the answer to the last question is yes, improve the code first.
