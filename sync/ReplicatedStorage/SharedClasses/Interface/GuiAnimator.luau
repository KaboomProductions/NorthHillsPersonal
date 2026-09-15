local runService = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")

local sharedClasses = replicatedStorage.SharedClasses

local springModule = require(sharedClasses.Spring)
local uiCacheModule = require(sharedClasses.Interface.UiCache)

--//--------------------------------------------------------------------------------//
--// TYPES
--//--------------------------------------------------------------------------------//

export type EasingStyle = "linear" | "quad" | "cubic" | "quart" | "sine" | "expo" | "circ" | "back" | "elastic" | "bounce"
export type EasingDirection = "in" | "out" | "inout"

--//--------------------------------------------------------------------------------//
--// INTERNAL UTILITIES
--//--------------------------------------------------------------------------------//

local function offsetToUdim2(offset: Vector2): UDim2
	return UDim2.fromOffset(offset.X, offset.Y)
end

local function expLerpAlpha(speed: number, deltaTime: number): number
	return 1 - math.exp(-speed * deltaTime)
end

local function lerpColor3RGB(a: Color3, b: Color3, t: number): Color3
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

local function lerpColor3HSV(a: Color3, b: Color3, t: number): Color3
	local ah, as_, av = a:ToHSV()
	local bh, bs, bv = b:ToHSV()
	--// Shortest path on hue wheel
	local dh = bh - ah
	if dh > 0.5 then
		dh -= 1
	elseif dh < -0.5 then
		dh += 1
	end
	return Color3.fromHSV((ah + dh * t) % 1, as_ + (bs - as_) * t, av + (bv - av) * t)
end

local function createSpring(initial: Vector2, frequency: number, damping: number, mass: number, speed: number)
	return springModule.new(initial, frequency, damping, mass, speed)
end

--//--------------------------------------------------------------------------------//
--// EASING LIBRARY
--//--------------------------------------------------------------------------------//

local easingFunctions: { [string]: { [string]: (t: number) -> number } } = {}

easingFunctions["linear"] = {
	["in"] = function(t)
		return t
	end,
	["out"] = function(t)
		return t
	end,
	["inout"] = function(t)
		return t
	end,
}
easingFunctions["quad"] = {
	["in"] = function(t)
		return t * t
	end,
	["out"] = function(t)
		return t * (2 - t)
	end,
	["inout"] = function(t)
		return t < 0.5 and 2 * t * t or -1 + (4 - 2 * t) * t
	end,
}
easingFunctions["cubic"] = {
	["in"] = function(t)
		return t * t * t
	end,
	["out"] = function(t)
		local s = t - 1
		return s * s * s + 1
	end,
	["inout"] = function(t)
		if t < 0.5 then
			return 4 * t * t * t
		else
			local s = 2 * t - 2
			return 1 + s * s * s / 2
		end
	end,
}
easingFunctions["quart"] = {
	["in"] = function(t)
		return t * t * t * t
	end,
	["out"] = function(t)
		local s = t - 1
		return 1 - s * s * s * s
	end,
	["inout"] = function(t)
		if t < 0.5 then
			return 8 * t * t * t * t
		else
			local s = t - 1
			return 1 - 8 * s * s * s * s
		end
	end,
}
easingFunctions["sine"] = {
	["in"] = function(t)
		return 1 - math.cos(t * math.pi / 2)
	end,
	["out"] = function(t)
		return math.sin(t * math.pi / 2)
	end,
	["inout"] = function(t)
		return (1 - math.cos(math.pi * t)) / 2
	end,
}
easingFunctions["expo"] = {
	["in"] = function(t)
		return t == 0 and 0 or 2 ^ (10 * t - 10)
	end,
	["out"] = function(t)
		return t == 1 and 1 or 1 - 2 ^ (-10 * t)
	end,
	["inout"] = function(t)
		if t == 0 then
			return 0
		end
		if t == 1 then
			return 1
		end
		if t < 0.5 then
			return 2 ^ (20 * t - 10) / 2
		else
			return (2 - 2 ^ (-20 * t + 10)) / 2
		end
	end,
}
easingFunctions["circ"] = {
	["in"] = function(t)
		return 1 - math.sqrt(1 - t * t)
	end,
	["out"] = function(t)
		local s = t - 1
		return math.sqrt(1 - s * s)
	end,
	["inout"] = function(t)
		if t < 0.5 then
			return (1 - math.sqrt(1 - 4 * t * t)) / 2
		else
			local s = -2 * t + 2
			return (math.sqrt(1 - s * s) + 1) / 2
		end
	end,
}
easingFunctions["back"] = {
	["in"] = function(t)
		local c = 1.70158
		return t * t * ((c + 1) * t - c)
	end,
	["out"] = function(t)
		local c = 1.70158
		local s = t - 1
		return s * s * ((c + 1) * s + c) + 1
	end,
	["inout"] = function(t)
		local c = 1.70158 * 1.525
		if t < 0.5 then
			return (4 * t * t * ((c + 1) * 2 * t - c)) / 2
		else
			local s = 2 * t - 2
			return (s * s * ((c + 1) * s + c) + 2) / 2
		end
	end,
}
easingFunctions["elastic"] = {
	["in"] = function(t)
		if t == 0 then
			return 0
		end
		if t == 1 then
			return 1
		end
		return -(2 ^ (10 * t - 10)) * math.sin((t * 10 - 10.75) * (2 * math.pi / 3))
	end,
	["out"] = function(t)
		if t == 0 then
			return 0
		end
		if t == 1 then
			return 1
		end
		return 2 ^ (-10 * t) * math.sin((t * 10 - 0.75) * (2 * math.pi / 3)) + 1
	end,
	["inout"] = function(t)
		if t == 0 then
			return 0
		end
		if t == 1 then
			return 1
		end
		if t < 0.5 then
			return -(2 ^ (20 * t - 10) * math.sin((20 * t - 11.125) * (2 * math.pi / 4.5))) / 2
		else
			return (2 ^ (-20 * t + 10) * math.sin((20 * t - 11.125) * (2 * math.pi / 4.5))) / 2 + 1
		end
	end,
}
do
	local function bounceOut(t)
		local n1, d1 = 7.5625, 2.75
		if t < 1 / d1 then
			return n1 * t * t
		elseif t < 2 / d1 then
			t -= 1.5 / d1
			return n1 * t * t + 0.75
		elseif t < 2.5 / d1 then
			t -= 2.25 / d1
			return n1 * t * t + 0.9375
		else
			t -= 2.625 / d1
			return n1 * t * t + 0.984375
		end
	end
	easingFunctions["bounce"] = {
		["out"] = bounceOut,
		["in"] = function(t)
			return 1 - bounceOut(1 - t)
		end,
		["inout"] = function(t)
			if t < 0.5 then
				return (1 - bounceOut(1 - 2 * t)) / 2
			else
				return (1 + bounceOut(2 * t - 1)) / 2
			end
		end,
	}
end

local function applyEasing(t: number, style: EasingStyle?, direction: EasingDirection?): number
	local group = easingFunctions[style or "linear"]
	if not group then
		return t
	end
	local fn = group[direction or "out"] or group["out"]
	return fn(t)
end

--//--------------------------------------------------------------------------------//
--// GUIANIMATOR
--//--------------------------------------------------------------------------------//

local guiAnimator = {}
guiAnimator.__index = guiAnimator

--//================================================================================//
--// SPRING API
--//================================================================================//

function guiAnimator:addSpring(
	springKey: string,
	initial: Vector2,
	frequency: number,
	damping: number,
	mass: number,
	speed: number
)
	self.springs[springKey] = createSpring(initial, frequency, damping, mass, speed)
end

--// Scalar (1-D) spring. Value is stored in the X component.
function guiAnimator:addScalarSpring(
	springKey: string,
	initial: number,
	frequency: number,
	damping: number,
	mass: number,
	speed: number
)
	self.springs[springKey] = createSpring(Vector2.new(initial, 0), frequency, damping, mass, speed)
end

function guiAnimator:getSpring(springKey: string)
	local spring = self.springs[springKey]
	if not spring then
		error(("missingSpring: %s"):format(springKey))
	end
	return spring
end

function guiAnimator:hasSpring(springKey: string): boolean
	return self.springs[springKey] ~= nil
end

--// Set spring target, and optionally velocity and position.
function guiAnimator:setSpring(springKey: string, target: Vector2, velocity: Vector2?, position: Vector2?)
	local spring = self:getSpring(springKey)
	spring.target = target

	if velocity ~= nil then
		spring.velocity = velocity
	end

	if position ~= nil then
		spring.position = position
	end
end

--// Teleport the spring to a new position with zero velocity and matching target.
function guiAnimator:snapSpring(springKey: string, position: Vector2)
	local spring = self:getSpring(springKey)
	spring.position = position
	spring.target = position
	spring.velocity = Vector2.zero
end

--// Add an instantaneous velocity impulse without changing the target.
function guiAnimator:impulseSpring(springKey: string, impulse: Vector2)
	local spring = self:getSpring(springKey)
	spring.velocity = spring.velocity + impulse
end

--// Change spring parameters at runtime without disrupting current state.
function guiAnimator:configureSpring(
	springKey: string,
	frequency: number?,
	damping: number?,
	mass: number?,
	speed: number?
)
	local spring = self:getSpring(springKey)
	if frequency then
		spring.frequency = frequency
	end
	if damping then
		spring.damping = damping
	end
	if mass then
		spring.mass = mass
	end
	if speed then
		spring.speed = speed
	end
end

--// Returns true when the spring has settled within threshold distance and velocity.
function guiAnimator:isSpringSettled(springKey: string, posThreshold: number?, velThreshold: number?): boolean
	local spring = self:getSpring(springKey)
	local dp = spring.position - spring.target
	return dp.Magnitude < (posThreshold or 0.001) and spring.velocity.Magnitude < (velThreshold or 0.001)
end

--// Read current spring state without modifying it.
function guiAnimator:getSpringState(springKey: string): (Vector2, Vector2, Vector2)
	local spring = self:getSpring(springKey)
	return spring.position, spring.velocity, spring.target
end

function guiAnimator:removeSpring(springKey: string)
	self.springs[springKey] = nil
end

--//================================================================================//
--// TRACK: OFFSET  (spring-driven UDim2 offset on top of a cached base value)
--//================================================================================//

function guiAnimator:addOffsetTrack(trackKey: string, guiObject: GuiObject, propertyName: string, springKey: string)
	self.tracks[trackKey] = {
		kind = "offset",
		guiObject = guiObject,
		propertyName = propertyName,
		baseValue = self.uiCache:get(guiObject, propertyName),
		springKey = springKey,
	}
end

function guiAnimator:refreshOffsetBase(trackKey: string)
	local track = self.tracks[trackKey]
	if not track or track.kind ~= "offset" then
		return
	end
	track.baseValue = self.uiCache:get(track.guiObject, track.propertyName)
end

--//================================================================================//
--// TRACK: SIZE LERP
--//================================================================================//

function guiAnimator:addSizeLerpTrack(
	trackKey: string,
	guiObject: GuiObject,
	propertyName: string,
	currentValue: UDim2,
	targetValue: UDim2,
	speed: number
)
	self.tracks[trackKey] = {
		kind = "sizeLerp",
		guiObject = guiObject,
		propertyName = propertyName,
		currentValue = currentValue,
		targetValue = targetValue,
		speed = speed,
	}
	(guiObject :: any)[propertyName] = currentValue
end

function guiAnimator:setSizeLerpTarget(trackKey: string, targetValue: UDim2, speed: number?)
	local track = self.tracks[trackKey]
	if not track or track.kind ~= "sizeLerp" then
		error(("missingSizeLerpTrack: %s"):format(trackKey))
	end
	track.targetValue = targetValue
	if speed then
		track.speed = speed
	end
end

--// Instantly jump to value without animating.
function guiAnimator:snapSizeLerp(trackKey: string, value: UDim2)
	local track = self.tracks[trackKey]
	if not track or track.kind ~= "sizeLerp" then
		return
	end
	track.currentValue = value
	track.targetValue = value;
	(track.guiObject :: any)[track.propertyName] = value
end

--//================================================================================//
--// TRACK: SIZE SPRING  (spring-driven UDim2 size from a Vector2)
--//================================================================================//

--// Spring directly drives a Size/Position-like UDim2 via a Vector2 spring.
--// Set useOffset=true to use fromOffset instead of fromScale.
function guiAnimator:addSizeSpringTrack(
	trackKey: string,
	guiObject: GuiObject,
	propertyName: string,
	springKey: string,
	useOffset: boolean?
)
	self.tracks[trackKey] = {
		kind = "sizeSpring",
		guiObject = guiObject,
		propertyName = propertyName,
		springKey = springKey,
		useOffset = useOffset or false,
	}
end

--//================================================================================//
--// TRACK: POSITION SPRING  (spring directly drives Position UDim2)
--//================================================================================//

function guiAnimator:addPositionSpringTrack(
	trackKey: string,
	guiObject: GuiObject,
	springKey: string,
	useOffset: boolean?
)
	self.tracks[trackKey] = {
		kind = "positionSpring",
		guiObject = guiObject,
		springKey = springKey,
		useOffset = useOffset or false,
	}
end

--//================================================================================//
--// TRACK: ROTATION LERP
--//================================================================================//

function guiAnimator:addRotationLerpTrack(
	trackKey: string,
	guiObject: GuiObject,
	currentValue: number,
	targetValue: number,
	speed: number
)
	self.tracks[trackKey] = {
		kind = "rotationLerp",
		guiObject = guiObject,
		currentValue = currentValue,
		targetValue = targetValue,
		speed = speed,
	}
	guiObject.Rotation = currentValue
end

function guiAnimator:setRotationLerpTarget(trackKey: string, targetValue: number, speed: number?)
	local track = self.tracks[trackKey]
	if not track or track.kind ~= "rotationLerp" then
		error(("missingRotationLerpTrack: %s"):format(trackKey))
	end
	track.targetValue = targetValue
	if speed then
		track.speed = speed
	end
end

function guiAnimator:snapRotationLerp(trackKey: string, value: number)
	local track = self.tracks[trackKey]
	if not track or track.kind ~= "rotationLerp" then
		return
	end
	track.currentValue = value
	track.targetValue = value
	track.guiObject.Rotation = value
end

--//================================================================================//
--// TRACK: ROTATION SPRING
--//================================================================================//

function guiAnimator:addRotationSpringTrack(trackKey: string, guiObject: GuiObject, springKey: string)
	self.tracks[trackKey] = {
		kind = "rotationSpring",
		guiObject = guiObject,
		baseValue = self.uiCache:get(guiObject, "Rotation"),
		springKey = springKey,
	}
end

function guiAnimator:refreshRotationBase(trackKey: string)
	local track = self.tracks[trackKey]
	if not track or track.kind ~= "rotationSpring" then
		return
	end
	track.baseValue = self.uiCache:get(track.guiObject, "Rotation")
end

--//================================================================================//
--// TRACK: NUMBER LERP
--//================================================================================//

function guiAnimator:addNumberLerpTrack(
	trackKey: string,
	apply: (value: number) -> (),
	currentValue: number,
	targetValue: number,
	speed: number
)
	self.tracks[trackKey] = {
		kind = "numberLerp",
		apply = apply,
		currentValue = currentValue,
		targetValue = targetValue,
		speed = speed,
	}
	apply(currentValue)
end

function guiAnimator:setNumberLerpTarget(trackKey: string, targetValue: number, speed: number?)
	local track = self.tracks[trackKey]
	if not track or track.kind ~= "numberLerp" then
		error(("missingNumberLerpTrack: %s"):format(trackKey))
	end
	track.targetValue = targetValue
	if speed then
		track.speed = speed
	end
end

function guiAnimator:snapNumberLerp(trackKey: string, value: number)
	local track = self.tracks[trackKey]
	if not track or track.kind ~= "numberLerp" then
		return
	end
	track.currentValue = value
	track.targetValue = value
	track.apply(value)
end

--//================================================================================//
--// TRACK: NUMBER SPRING  (scalar spring via callback, uses spring.X)
--//================================================================================//

--// Spring-driven scalar. The spring's X component is added to baseValue and passed to apply.
function guiAnimator:addNumberSpringTrack(
	trackKey: string,
	apply: (value: number) -> (),
	springKey: string,
	baseValue: number?
)
	self.tracks[trackKey] = {
		kind = "numberSpring",
		apply = apply,
		springKey = springKey,
		baseValue = baseValue or 0,
	}
end

function guiAnimator:setNumberSpringBase(trackKey: string, baseValue: number)
	local track = self.tracks[trackKey]
	if not track or track.kind ~= "numberSpring" then
		return
	end
	track.baseValue = baseValue
end

--//================================================================================//
--// TRACK: COLOR LERP
--//================================================================================//

--// Exponential lerp between two Color3 values.
--// mode: "rgb" (default) or "hsv" for perceptually smoother hue transitions.
function guiAnimator:addColorLerpTrack(
	trackKey: string,
	apply: (value: Color3) -> (),
	currentValue: Color3,
	targetValue: Color3,
	speed: number,
	mode: string?
)
	self.tracks[trackKey] = {
		kind = "colorLerp",
		apply = apply,
		currentValue = currentValue,
		targetValue = targetValue,
		speed = speed,
		mode = mode or "rgb",
	}
	apply(currentValue)
end

function guiAnimator:setColorLerpTarget(trackKey: string, targetValue: Color3, speed: number?)
	local track = self.tracks[trackKey]
	if not track or track.kind ~= "colorLerp" then
		error(("missingColorLerpTrack: %s"):format(trackKey))
	end
	track.targetValue = targetValue
	if speed then
		track.speed = speed
	end
end

function guiAnimator:snapColorLerp(trackKey: string, value: Color3)
	local track = self.tracks[trackKey]
	if not track or track.kind ~= "colorLerp" then
		return
	end
	track.currentValue = value
	track.targetValue = value
	track.apply(value)
end

--//================================================================================//
--// TRACK: TRANSPARENCY LERP  (convenience wrapper)
--//================================================================================//

--// Shorthand for lerping any 0-1 transparency property directly on a GuiObject.
function guiAnimator:addTransparencyLerpTrack(
	trackKey: string,
	guiObject: GuiObject,
	propertyName: string,
	currentValue: number,
	targetValue: number,
	speed: number
)
	self:addNumberLerpTrack(trackKey, function(v)
		(guiObject :: any)[propertyName] = v
	end, currentValue, targetValue, speed)
end

function guiAnimator:setTransparencyLerpTarget(trackKey: string, targetValue: number, speed: number?)
	self:setNumberLerpTarget(trackKey, targetValue, speed)
end

--//================================================================================//
--// TRACK: TIMED LERP  (fixed-duration lerp with easing + completion callback)
--//================================================================================//

--// A one-shot lerp over `duration` seconds. `apply` receives an eased t in [0, 1].
--// Fires onComplete (deferred) when finished. Track auto-marks finished but stays in table.
function guiAnimator:addTimedLerpTrack(
	trackKey: string,
	apply: (easedT: number) -> (),
	duration: number,
	easingStyle: EasingStyle?,
	easingDirection: EasingDirection?,
	onComplete: (() -> ())?
)
	self.tracks[trackKey] = {
		kind = "timedLerp",
		apply = apply,
		duration = duration,
		elapsed = 0,
		easingStyle = easingStyle or "linear",
		easingDirection = easingDirection or "out",
		onComplete = onComplete,
		finished = false,
	}
	apply(applyEasing(0, easingStyle, easingDirection or "out"))
end

--// Restart a timed lerp from t=0.
function guiAnimator:restartTimedLerp(
	trackKey: string,
	duration: number?,
	easingStyle: EasingStyle?,
	easingDirection: EasingDirection?
)
	local track = self.tracks[trackKey]
	if not track or track.kind ~= "timedLerp" then
		return
	end
	track.elapsed = 0
	track.finished = false
	if duration then
		track.duration = duration
	end
	if easingStyle then
		track.easingStyle = easingStyle
	end
	if easingDirection then
		track.easingDirection = easingDirection
	end
end

function guiAnimator:isTimedLerpFinished(trackKey: string): boolean
	local track = self.tracks[trackKey]
	return track ~= nil and track.kind == "timedLerp" and track.finished == true
end

--//================================================================================//
--// TRACK MANAGEMENT UTILITIES
--//================================================================================//

function guiAnimator:removeTrack(trackKey: string)
	self.tracks[trackKey] = nil
end

function guiAnimator:hasTrack(trackKey: string): boolean
	return self.tracks[trackKey] ~= nil
end

--// Pause a data track so it skips applyTracks each frame.
function guiAnimator:pauseTrack(trackKey: string)
	local track = self.tracks[trackKey]
	if track then
		track._paused = true
	end
end

function guiAnimator:resumeTrack(trackKey: string)
	local track = self.tracks[trackKey]
	if track then
		track._paused = nil
	end
end

--// Change the lerp speed of any speed-bearing track mid-flight.
function guiAnimator:setTrackSpeed(trackKey: string, speed: number)
	local track = self.tracks[trackKey]
	if track and track.speed ~= nil then
		track.speed = speed
	end
end

--// Snap ALL lerp tracks to their targets instantly.
function guiAnimator:snapAll()
	for key, track in pairs(self.tracks) do
		if track.kind == "sizeLerp" then
			self:snapSizeLerp(key, track.targetValue)
		elseif track.kind == "numberLerp" then
			self:snapNumberLerp(key, track.targetValue)
		elseif track.kind == "rotationLerp" then
			self:snapRotationLerp(key, track.targetValue)
		elseif track.kind == "colorLerp" then
			self:snapColorLerp(key, track.targetValue)
		end
	end
end

--// Teleport ALL springs to their current targets.
function guiAnimator:snapAllSprings()
	for key in pairs(self.springs) do
		local spring = self.springs[key]
		self:snapSpring(key, spring.target)
	end
end

--//================================================================================//
--// APPLY TRACKS  (called each frame)
--//================================================================================//

function guiAnimator:applyTracks(deltaTime: number)
	for _, track in pairs(self.tracks) do
		if track._paused then
			continue
		end

		local kind = track.kind

		if kind == "offset" then
			local spring = self.springs[track.springKey]
			if spring then
				local offset = spring:update(deltaTime)
				track.guiObject[track.propertyName] = track.baseValue + offsetToUdim2(offset)
			end
		elseif kind == "sizeLerp" then
			local alpha = expLerpAlpha(track.speed, deltaTime)
			track.currentValue = track.currentValue:Lerp(track.targetValue, alpha)
			track.guiObject[track.propertyName] = track.currentValue
		elseif kind == "sizeSpring" then
			local spring = self.springs[track.springKey]
			if spring then
				local v = spring:update(deltaTime)
				track.guiObject[track.propertyName] = if track.useOffset
					then UDim2.fromOffset(v.X, v.Y)
					else UDim2.fromScale(v.X, v.Y)
			end
		elseif kind == "positionSpring" then
			local spring = self.springs[track.springKey]
			if spring then
				local v = spring:update(deltaTime)
				track.guiObject.Position = if track.useOffset
					then UDim2.fromOffset(v.X, v.Y)
					else UDim2.fromScale(v.X, v.Y)
			end
		elseif kind == "rotationLerp" then
			local alpha = expLerpAlpha(track.speed, deltaTime)
			track.currentValue = track.currentValue + (track.targetValue - track.currentValue) * alpha
			track.guiObject.Rotation = track.currentValue
		elseif kind == "rotationSpring" then
			local spring = self.springs[track.springKey]
			if spring then
				local offset = spring:update(deltaTime)
				track.guiObject.Rotation = track.baseValue + offset.X
			end
		elseif kind == "numberLerp" then
			local alpha = expLerpAlpha(track.speed, deltaTime)
			track.currentValue = track.currentValue + (track.targetValue - track.currentValue) * alpha
			track.apply(track.currentValue)
		elseif kind == "numberSpring" then
			local spring = self.springs[track.springKey]
			if spring then
				local v = spring:update(deltaTime)
				track.apply(track.baseValue + v.X)
			end
		elseif kind == "colorLerp" then
			local alpha = expLerpAlpha(track.speed, deltaTime)
			if track.mode == "hsv" then
				track.currentValue = lerpColor3HSV(track.currentValue, track.targetValue, alpha)
			else
				track.currentValue = lerpColor3RGB(track.currentValue, track.targetValue, alpha)
			end
			track.apply(track.currentValue)
		elseif kind == "timedLerp" then
			if track.finished then
				continue
			end
			track.elapsed = track.elapsed + deltaTime
			local rawT = math.clamp(track.elapsed / track.duration, 0, 1)
			local easedT = applyEasing(rawT, track.easingStyle, track.easingDirection)
			track.apply(easedT)
			if rawT >= 1 then
				track.finished = true
				if track.onComplete then
					task.defer(track.onComplete)
				end
			end
		end
	end
end

--//================================================================================//
--// ANIMATION TRACKS  (RenderStepped-bound playback sessions)
--//================================================================================//

function guiAnimator:createTrack(trackName: string?)
	local name = trackName or "main"
	if self.animationTracks[name] then
		return self.animationTracks[name]
	end
	self.animationTracks[name] = {
		name = name,
		activeName = nil,
		activeCleanup = nil,
		connection = nil,
		paused = false,
	}
	return self.animationTracks[name]
end

function guiAnimator:stopTrack(trackName: string?)
	local name = trackName or "main"
	local track = self.animationTracks[name]
	if not track then
		return
	end

	if track.connection then
		track.connection:Disconnect()
		track.connection = nil
	end

	if track.activeCleanup then
		track.activeCleanup()
		track.activeCleanup = nil
	end

	track.activeName = nil
	track.paused = false
end

function guiAnimator:cancel(trackName: string?)
	self:stopTrack(trackName)
end

function guiAnimator:pauseAnimationTrack(trackName: string?)
	local track = self.animationTracks[trackName or "main"]
	if track then
		track.paused = true
	end
end

function guiAnimator:resumeAnimationTrack(trackName: string?)
	local track = self.animationTracks[trackName or "main"]
	if track then
		track.paused = false
	end
end

function guiAnimator:isAnimationTrackPlaying(trackName: string?): boolean
	local track = self.animationTracks[trackName or "main"]
	return track ~= nil and track.activeName ~= nil
end

function guiAnimator:getActiveAnimationName(trackName: string?): string?
	local track = self.animationTracks[trackName or "main"]
	return track and track.activeName
end

--// Play an animation on a named track.
--// updateFunction returns true when the animation is finished.
function guiAnimator:play(
	trackName: string?,
	animationName: string,
	updateFunction: (deltaTime: number) -> boolean,
	cleanupFunction: (() -> ())?,
	finishedFunction: (() -> ())?
)
	local name = trackName or "main"
	local track = self:createTrack(name)

	self:stopTrack(name)

	track.activeName = animationName
	track.activeCleanup = cleanupFunction

	track.connection = runService.RenderStepped:Connect(function(deltaTime: number)
		if track.paused then
			return
		end

		self:applyTracks(deltaTime)

		local isDone = updateFunction(deltaTime)
		if isDone and track.activeName == animationName then
			self:stopTrack(name)
			if finishedFunction then
				finishedFunction()
			end
		end
	end)
end

--// Play a sequence of animations back-to-back on the same track.
--// Each entry in `sequence` is { animationName, updateFn, cleanupFn? }.
function guiAnimator:playSequence(trackName: string?, sequence: { { any } }, onAllFinished: (() -> ())?)
	local name = trackName or "main"
	local index = 0

	local function playNext()
		index += 1
		if index > #sequence then
			if onAllFinished then
				onAllFinished()
			end
			return
		end
		local entry = sequence[index]
		local animName = entry[1] :: string
		local updateFn = entry[2] :: (deltaTime: number) -> boolean
		local cleanupFn = entry[3] :: (() -> ())?
		self:play(name, animName, updateFn, cleanupFn, playNext)
	end

	playNext()
end

--//================================================================================//
--// CONSTRUCTOR / DESTRUCTOR
--//================================================================================//

function guiAnimator.new(rootGui: GuiObject)
	local self = setmetatable({}, guiAnimator)

	self.uiCache = uiCacheModule.new()
	self.uiCache:cache(rootGui)

	self.springs = {}
	self.tracks = {}
	self.animationTracks = {}

	self:createTrack("main")

	return self
end

function guiAnimator:destroy()
	for trackName in pairs(self.animationTracks) do
		self:stopTrack(trackName)
	end

	table.clear(self.animationTracks)
	table.clear(self.tracks)
	table.clear(self.springs)

	setmetatable(self, nil)
end

return guiAnimator
