--!strict
--!optimize 2

--//[[
--//	S8		Minimum: -128			Maximum: 127
--//	S16		Minimum: -32768			Maximum: 32767
--//	S24		Minimum: -8388608		Maximum: 8388607
--//	S32		Minimum: -2147483648	Maximum: 2147483647
--//
--//	U8		Minimum: 0				Maximum: 255
--//	U16		Minimum: 0				Maximum: 65535
--//	U24		Minimum: 0				Maximum: 16777215
--//	U32		Minimum: 0				Maximum: 4294967295
--//
--//	F16		±2048					[65520]
--//	F24		±262144					[4294959104]
--//	F32		±16777216				[170141183460469231731687303715884105728]
--//	F64		±9007199254740992		[huge]
--//]]

--// Types
export type Cursor = {
	Buffer: buffer,
	BufferLength: number,
	BufferOffset: number,
	Instances: { Instance },
	InstancesOffset: number,
}

--// Variables
local activeCursor: Cursor
local activeBuffer: buffer
local bufferLength: number
local bufferOffset: number
local activeInstances: { Instance }
local instancesOffset: number
local typeSpecifiers = {}
local readFunctions = {}
local writeFunctions = {}
local anyReadFunctions = {} :: { [any]: () -> any }
local anyWriteFunctions = {} :: { [any]: (any) -> () }

local bufferLibrary = buffer :: any --// silence Rojo's type checker since it doesn't know about the buffer library's bit level functions

local function bufferReadBits(sourceBuffer: buffer, bitOffset: number, bitCount: number): number
	return bufferLibrary.readbits(sourceBuffer, bitOffset, bitCount)
end

local function bufferWriteBits(sourceBuffer: buffer, bitOffset: number, bitCount: number, value: number)
	bufferLibrary.writebits(sourceBuffer, bitOffset, bitCount, value)
end

--// Buffer Primitives
local function allocateBytes(byteCount: number)
	local targetLength = bufferOffset + byteCount
	if bufferLength < targetLength then
		while bufferLength < targetLength do
			bufferLength *= 2
		end
		local newBuffer = buffer.create(bufferLength)
		buffer.copy(newBuffer, 0, activeBuffer, 0, bufferOffset)
		activeCursor.Buffer = newBuffer
		activeBuffer = newBuffer
	end
end

local function readS8(): number
	local value = buffer.readi8(activeBuffer, bufferOffset)
	bufferOffset += 1
	return value
end
local function writeS8(value: number)
	buffer.writei8(activeBuffer, bufferOffset, value)
	bufferOffset += 1
end
local function readS16(): number
	local value = buffer.readi16(activeBuffer, bufferOffset)
	bufferOffset += 2
	return value
end
local function writeS16(value: number)
	buffer.writei16(activeBuffer, bufferOffset, value)
	bufferOffset += 2
end
local function readS24(): number
	local value = bufferReadBits(activeBuffer, bufferOffset * 8, 24) - 8388608
	bufferOffset += 3
	return value
end
local function writeS24(value: number)
	bufferWriteBits(activeBuffer, bufferOffset * 8, 24, value + 8388608)
	bufferOffset += 3
end
local function readS32(): number
	local value = buffer.readi32(activeBuffer, bufferOffset)
	bufferOffset += 4
	return value
end
local function writeS32(value: number)
	buffer.writei32(activeBuffer, bufferOffset, value)
	bufferOffset += 4
end
local function readU8(): number
	local value = buffer.readu8(activeBuffer, bufferOffset)
	bufferOffset += 1
	return value
end
local function writeU8(value: number)
	buffer.writeu8(activeBuffer, bufferOffset, value)
	bufferOffset += 1
end
local function readU16(): number
	local value = buffer.readu16(activeBuffer, bufferOffset)
	bufferOffset += 2
	return value
end
local function writeU16(value: number)
	buffer.writeu16(activeBuffer, bufferOffset, value)
	bufferOffset += 2
end
local function readU24(): number
	local value = bufferReadBits(activeBuffer, bufferOffset * 8, 24)
	bufferOffset += 3
	return value
end
local function writeU24(value: number)
	bufferWriteBits(activeBuffer, bufferOffset * 8, 24, value)
	bufferOffset += 3
end
local function readU32(): number
	local value = buffer.readu32(activeBuffer, bufferOffset)
	bufferOffset += 4
	return value
end
local function writeU32(value: number)
	buffer.writeu32(activeBuffer, bufferOffset, value)
	bufferOffset += 4
end
local function readF32(): number
	local value = buffer.readf32(activeBuffer, bufferOffset)
	bufferOffset += 4
	return value
end
local function writeF32(value: number)
	buffer.writef32(activeBuffer, bufferOffset, value)
	bufferOffset += 4
end
local function readF64(): number
	local value = buffer.readf64(activeBuffer, bufferOffset)
	bufferOffset += 8
	return value
end
local function writeF64(value: number)
	buffer.writef64(activeBuffer, bufferOffset, value)
	bufferOffset += 8
end
local function readStringFromBuffer(length: number)
	local value = buffer.readstring(activeBuffer, bufferOffset, length)
	bufferOffset += length
	return value
end
local function writeStringToBuffer(value: string)
	buffer.writestring(activeBuffer, bufferOffset, value)
	bufferOffset += #value
end
local function readBufferFromBuffer(length: number)
	local value = buffer.create(length)
	buffer.copy(value, 0, activeBuffer, bufferOffset, length)
	bufferOffset += length
	return value
end
local function writeBufferToBuffer(value: buffer)
	buffer.copy(activeBuffer, bufferOffset, value)
	bufferOffset += buffer.len(value)
end
local function readInstance()
	instancesOffset += 1
	return activeInstances[instancesOffset]
end
local function writeInstance(value)
	instancesOffset += 1
	activeInstances[instancesOffset] = value
end

--// Half-Precision Float (F16)
local function readF16(): number
	local bitOffset = bufferOffset * 8
	bufferOffset += 2
	local mantissa = bufferReadBits(activeBuffer, bitOffset + 0, 10)
	local exponent = bufferReadBits(activeBuffer, bitOffset + 10, 5)
	local sign = bufferReadBits(activeBuffer, bitOffset + 15, 1)
	if mantissa == 0b0000000000 then
		if exponent == 0b00000 then
			return 0
		end
		if exponent == 0b11111 then
			return if sign == 0 then math.huge else -math.huge
		end
	elseif exponent == 0b11111 then
		return 0 / 0
	end
	if sign == 0 then
		return (mantissa / 1024 + 1) * 2 ^ (exponent - 15)
	else
		return -(mantissa / 1024 + 1) * 2 ^ (exponent - 15)
	end
end
local function writeF16(value: number)
	local bitOffset = bufferOffset * 8
	bufferOffset += 2
	if value == 0 then
		bufferWriteBits(activeBuffer, bitOffset, 16, 0b0_00000_0000000000)
	elseif value >= 65520 then
		bufferWriteBits(activeBuffer, bitOffset, 16, 0b0_11111_0000000000)
	elseif value <= -65520 then
		bufferWriteBits(activeBuffer, bitOffset, 16, 0b1_11111_0000000000)
	elseif value ~= value then
		bufferWriteBits(activeBuffer, bitOffset, 16, 0b0_11111_0000000001)
	else
		local sign = 0
		if value < 0 then
			sign = 1
			value = -value
		end
		local mantissa, exponent = math.frexp(value)
		bufferWriteBits(activeBuffer, bitOffset + 0, 10, mantissa * 2048 - 1023.5)
		bufferWriteBits(activeBuffer, bitOffset + 10, 5, exponent + 14)
		bufferWriteBits(activeBuffer, bitOffset + 15, 1, sign)
	end
end

--// Three-Quarter Precision Float (F24)
local function readF24(): number
	local bitOffset = bufferOffset * 8
	bufferOffset += 3
	local mantissa = bufferReadBits(activeBuffer, bitOffset + 0, 17)
	local exponent = bufferReadBits(activeBuffer, bitOffset + 17, 6)
	local sign = bufferReadBits(activeBuffer, bitOffset + 23, 1)
	if mantissa == 0b00000000000000000 then
		if exponent == 0b000000 then
			return 0
		end
		if exponent == 0b111111 then
			return if sign == 0 then math.huge else -math.huge
		end
	elseif exponent == 0b111111 then
		return 0 / 0
	end
	if sign == 0 then
		return (mantissa / 131072 + 1) * 2 ^ (exponent - 31)
	else
		return -(mantissa / 131072 + 1) * 2 ^ (exponent - 31)
	end
end
local function writeF24(value: number)
	local bitOffset = bufferOffset * 8
	bufferOffset += 3
	if value == 0 then
		bufferWriteBits(activeBuffer, bitOffset, 24, 0b0_000000_00000000000000000)
	elseif value >= 4294959104 then
		bufferWriteBits(activeBuffer, bitOffset, 24, 0b0_111111_00000000000000000)
	elseif value <= -4294959104 then
		bufferWriteBits(activeBuffer, bitOffset, 24, 0b1_111111_00000000000000000)
	elseif value ~= value then
		bufferWriteBits(activeBuffer, bitOffset, 24, 0b0_111111_00000000000000001)
	else
		local sign = 0
		if value < 0 then
			sign = 1
			value = -value
		end
		local mantissa, exponent = math.frexp(value)
		bufferWriteBits(activeBuffer, bitOffset + 0, 17, mantissa * 262144 - 131071.5)
		bufferWriteBits(activeBuffer, bitOffset + 17, 6, exponent + 30)
		bufferWriteBits(activeBuffer, bitOffset + 23, 1, sign)
	end
end

--// Typed Serializers
typeSpecifiers.Any = "Any" :: any
readFunctions.Any = function()
	return anyReadFunctions[readU8()]()
end
writeFunctions.Any = function(value: any)
	anyWriteFunctions[typeof(value)](value)
end

typeSpecifiers.Nil = ("Nil" :: any) :: nil
readFunctions.Nil = function()
	return nil
end
writeFunctions.Nil = function(_value: nil) end

typeSpecifiers.NumberS8 = ("NumberS8" :: any) :: number
readFunctions.NumberS8 = function()
	return readS8()
end
writeFunctions.NumberS8 = function(value: number)
	allocateBytes(1)
	writeS8(value)
end

typeSpecifiers.NumberS16 = ("NumberS16" :: any) :: number
readFunctions.NumberS16 = function()
	return readS16()
end
writeFunctions.NumberS16 = function(value: number)
	allocateBytes(2)
	writeS16(value)
end

typeSpecifiers.NumberS24 = ("NumberS24" :: any) :: number
readFunctions.NumberS24 = function()
	return readS24()
end
writeFunctions.NumberS24 = function(value: number)
	allocateBytes(3)
	writeS24(value)
end

typeSpecifiers.NumberS32 = ("NumberS32" :: any) :: number
readFunctions.NumberS32 = function()
	return readS32()
end
writeFunctions.NumberS32 = function(value: number)
	allocateBytes(4)
	writeS32(value)
end

typeSpecifiers.NumberU8 = ("NumberU8" :: any) :: number
readFunctions.NumberU8 = function()
	return readU8()
end
writeFunctions.NumberU8 = function(value: number)
	allocateBytes(1)
	writeU8(value)
end

typeSpecifiers.NumberU16 = ("NumberU16" :: any) :: number
readFunctions.NumberU16 = function()
	return readU16()
end
writeFunctions.NumberU16 = function(value: number)
	allocateBytes(2)
	writeU16(value)
end

typeSpecifiers.NumberU24 = ("NumberU24" :: any) :: number
readFunctions.NumberU24 = function()
	return readU24()
end
writeFunctions.NumberU24 = function(value: number)
	allocateBytes(3)
	writeU24(value)
end

typeSpecifiers.NumberU32 = ("NumberU32" :: any) :: number
readFunctions.NumberU32 = function()
	return readU32()
end
writeFunctions.NumberU32 = function(value: number)
	allocateBytes(4)
	writeU32(value)
end

typeSpecifiers.NumberF16 = ("NumberF16" :: any) :: number
readFunctions.NumberF16 = function()
	return readF16()
end
writeFunctions.NumberF16 = function(value: number)
	allocateBytes(2)
	writeF16(value)
end

typeSpecifiers.NumberF24 = ("NumberF24" :: any) :: number
readFunctions.NumberF24 = function()
	return readF24()
end
writeFunctions.NumberF24 = function(value: number)
	allocateBytes(3)
	writeF24(value)
end

typeSpecifiers.NumberF32 = ("NumberF32" :: any) :: number
readFunctions.NumberF32 = function()
	return readF32()
end
writeFunctions.NumberF32 = function(value: number)
	allocateBytes(4)
	writeF32(value)
end

typeSpecifiers.NumberF64 = ("NumberF64" :: any) :: number
readFunctions.NumberF64 = function()
	return readF64()
end
writeFunctions.NumberF64 = function(value: number)
	allocateBytes(8)
	writeF64(value)
end

typeSpecifiers.String = ("String" :: any) :: string
readFunctions.String = function()
	return readStringFromBuffer(readU8())
end
writeFunctions.String = function(value: string)
	local length = #value
	allocateBytes(1 + length)
	writeU8(length)
	writeStringToBuffer(value)
end

typeSpecifiers.StringLong = ("StringLong" :: any) :: string
readFunctions.StringLong = function()
	return readStringFromBuffer(readU16())
end
writeFunctions.StringLong = function(value: string)
	local length = #value
	allocateBytes(2 + length)
	writeU16(length)
	writeStringToBuffer(value)
end

typeSpecifiers.Buffer = ("Buffer" :: any) :: buffer
readFunctions.Buffer = function()
	return readBufferFromBuffer(readU8())
end
writeFunctions.Buffer = function(value: buffer)
	local length = buffer.len(value)
	allocateBytes(1 + length)
	writeU8(length)
	writeBufferToBuffer(value)
end

typeSpecifiers.BufferLong = ("BufferLong" :: any) :: buffer
readFunctions.BufferLong = function()
	return readBufferFromBuffer(readU16())
end
writeFunctions.BufferLong = function(value: buffer)
	local length = buffer.len(value)
	allocateBytes(2 + length)
	writeU16(length)
	writeBufferToBuffer(value)
end

typeSpecifiers.Instance = ("Instance" :: any) :: Instance
readFunctions.Instance = function()
	return readInstance()
end
writeFunctions.Instance = function(value: Instance)
	writeInstance(value)
end

typeSpecifiers.Boolean8 = ("Boolean8" :: any) :: boolean
readFunctions.Boolean8 = function()
	return readU8() == 1
end
writeFunctions.Boolean8 = function(value: boolean)
	allocateBytes(1)
	writeU8(if value then 1 else 0)
end

typeSpecifiers.NumberRange = ("NumberRange" :: any) :: NumberRange
readFunctions.NumberRange = function()
	return NumberRange.new(readF32(), readF32())
end
writeFunctions.NumberRange = function(value: NumberRange)
	allocateBytes(8)
	writeF32(value.Min)
	writeF32(value.Max)
end

typeSpecifiers.BrickColor = ("BrickColor" :: any) :: BrickColor
readFunctions.BrickColor = function()
	return BrickColor.new(readU16())
end
writeFunctions.BrickColor = function(value: BrickColor)
	allocateBytes(2)
	writeU16(value.Number)
end

typeSpecifiers.Color3 = ("Color3" :: any) :: Color3
readFunctions.Color3 = function()
	return Color3.fromRGB(readU8(), readU8(), readU8())
end
writeFunctions.Color3 = function(value: Color3)
	allocateBytes(3)
	writeU8(value.R * 255 + 0.5)
	writeU8(value.G * 255 + 0.5)
	writeU8(value.B * 255 + 0.5)
end

typeSpecifiers.UDim = ("UDim" :: any) :: UDim
readFunctions.UDim = function()
	return UDim.new(readS16() / 1000, readS16())
end
writeFunctions.UDim = function(value: UDim)
	allocateBytes(4)
	writeS16(value.Scale * 1000)
	writeS16(value.Offset)
end

typeSpecifiers.UDim2 = ("UDim2" :: any) :: UDim2
readFunctions.UDim2 = function()
	return UDim2.new(readS16() / 1000, readS16(), readS16() / 1000, readS16())
end
writeFunctions.UDim2 = function(value: UDim2)
	allocateBytes(8)
	writeS16(value.X.Scale * 1000)
	writeS16(value.X.Offset)
	writeS16(value.Y.Scale * 1000)
	writeS16(value.Y.Offset)
end

typeSpecifiers.Rect = ("Rect" :: any) :: Rect
readFunctions.Rect = function()
	return Rect.new(readF32(), readF32(), readF32(), readF32())
end
writeFunctions.Rect = function(value: Rect)
	allocateBytes(16)
	writeF32(value.Min.X)
	writeF32(value.Min.Y)
	writeF32(value.Max.X)
	writeF32(value.Max.Y)
end

typeSpecifiers.Vector2S16 = ("Vector2S16" :: any) :: Vector2
readFunctions.Vector2S16 = function()
	return Vector2.new(readS16(), readS16())
end
writeFunctions.Vector2S16 = function(value: Vector2)
	allocateBytes(4)
	writeS16(value.X)
	writeS16(value.Y)
end

typeSpecifiers.Vector2F24 = ("Vector2F24" :: any) :: Vector2
readFunctions.Vector2F24 = function()
	return Vector2.new(readF24(), readF24())
end
writeFunctions.Vector2F24 = function(value: Vector2)
	allocateBytes(6)
	writeF24(value.X)
	writeF24(value.Y)
end

typeSpecifiers.Vector2F32 = ("Vector2F32" :: any) :: Vector2
readFunctions.Vector2F32 = function()
	return Vector2.new(readF32(), readF32())
end
writeFunctions.Vector2F32 = function(value: Vector2)
	allocateBytes(8)
	writeF32(value.X)
	writeF32(value.Y)
end

typeSpecifiers.Vector3S16 = ("Vector3S16" :: any) :: Vector3
readFunctions.Vector3S16 = function()
	return Vector3.new(readS16(), readS16(), readS16())
end
writeFunctions.Vector3S16 = function(value: Vector3)
	allocateBytes(6)
	writeS16(value.X)
	writeS16(value.Y)
	writeS16(value.Z)
end

typeSpecifiers.Vector3F24 = ("Vector3F24" :: any) :: Vector3
readFunctions.Vector3F24 = function()
	return Vector3.new(readF24(), readF24(), readF24())
end
writeFunctions.Vector3F24 = function(value: Vector3)
	allocateBytes(9)
	writeF24(value.X)
	writeF24(value.Y)
	writeF24(value.Z)
end

typeSpecifiers.Vector3F32 = ("Vector3F32" :: any) :: Vector3
readFunctions.Vector3F32 = function()
	return Vector3.new(readF32(), readF32(), readF32())
end
writeFunctions.Vector3F32 = function(value: Vector3)
	allocateBytes(12)
	writeF32(value.X)
	writeF32(value.Y)
	writeF32(value.Z)
end

typeSpecifiers.NumberU4 = ("NumberU4" :: any) :: { number }
readFunctions.NumberU4 = function()
	local bitOffset = bufferOffset * 8
	bufferOffset += 1
	return {
		bufferReadBits(activeBuffer, bitOffset + 0, 4),
		bufferReadBits(activeBuffer, bitOffset + 4, 4),
	}
end
writeFunctions.NumberU4 = function(value: { number })
	allocateBytes(1)
	local bitOffset = bufferOffset * 8
	bufferOffset += 1
	bufferWriteBits(activeBuffer, bitOffset + 0, 4, value[1])
	bufferWriteBits(activeBuffer, bitOffset + 4, 4, value[2])
end

typeSpecifiers.BooleanNumber = ("BooleanNumber" :: any) :: { Boolean: boolean, Number: number }
readFunctions.BooleanNumber = function()
	local bitOffset = bufferOffset * 8
	bufferOffset += 1
	return {
		Boolean = bufferReadBits(activeBuffer, bitOffset + 0, 1) == 1,
		Number = bufferReadBits(activeBuffer, bitOffset + 1, 7),
	}
end
writeFunctions.BooleanNumber = function(value: { Boolean: boolean, Number: number })
	allocateBytes(1)
	local bitOffset = bufferOffset * 8
	bufferOffset += 1
	bufferWriteBits(activeBuffer, bitOffset + 0, 1, if value.Boolean then 1 else 0)
	bufferWriteBits(activeBuffer, bitOffset + 1, 7, value.Number)
end

typeSpecifiers.Boolean1 = ("Boolean1" :: any) :: { boolean }
readFunctions.Boolean1 = function()
	local bitOffset = bufferOffset * 8
	bufferOffset += 1
	return {
		bufferReadBits(activeBuffer, bitOffset + 0, 1) == 1,
		bufferReadBits(activeBuffer, bitOffset + 1, 1) == 1,
		bufferReadBits(activeBuffer, bitOffset + 2, 1) == 1,
		bufferReadBits(activeBuffer, bitOffset + 3, 1) == 1,
		bufferReadBits(activeBuffer, bitOffset + 4, 1) == 1,
		bufferReadBits(activeBuffer, bitOffset + 5, 1) == 1,
		bufferReadBits(activeBuffer, bitOffset + 6, 1) == 1,
		bufferReadBits(activeBuffer, bitOffset + 7, 1) == 1,
	}
end
writeFunctions.Boolean1 = function(value: { boolean })
	allocateBytes(1)
	local bitOffset = bufferOffset * 8
	bufferOffset += 1
	bufferWriteBits(activeBuffer, bitOffset + 0, 1, if value[1] then 1 else 0)
	bufferWriteBits(activeBuffer, bitOffset + 1, 1, if value[2] then 1 else 0)
	bufferWriteBits(activeBuffer, bitOffset + 2, 1, if value[3] then 1 else 0)
	bufferWriteBits(activeBuffer, bitOffset + 3, 1, if value[4] then 1 else 0)
	bufferWriteBits(activeBuffer, bitOffset + 4, 1, if value[5] then 1 else 0)
	bufferWriteBits(activeBuffer, bitOffset + 5, 1, if value[6] then 1 else 0)
	bufferWriteBits(activeBuffer, bitOffset + 6, 1, if value[7] then 1 else 0)
	bufferWriteBits(activeBuffer, bitOffset + 7, 1, if value[8] then 1 else 0)
end

--// CFrame Serializers
typeSpecifiers.CFrameF24U8 = ("CFrameF24U8" :: any) :: CFrame
readFunctions.CFrameF24U8 = function()
	return CFrame.fromEulerAnglesXYZ(
		readU8() / 40.58451048843331,
		readU8() / 40.58451048843331,
		readU8() / 40.58451048843331
	) + Vector3.new(readF24(), readF24(), readF24())
end
writeFunctions.CFrameF24U8 = function(value: CFrame)
	local rotationX, rotationY, rotationZ = value:ToEulerAnglesXYZ()
	allocateBytes(12)
	writeU8(rotationX * 40.58451048843331 + 0.5)
	writeU8(rotationY * 40.58451048843331 + 0.5)
	writeU8(rotationZ * 40.58451048843331 + 0.5)
	writeF24(value.X)
	writeF24(value.Y)
	writeF24(value.Z)
end

typeSpecifiers.CFrameF32U8 = ("CFrameF32U8" :: any) :: CFrame
readFunctions.CFrameF32U8 = function()
	return CFrame.fromEulerAnglesXYZ(
		readU8() / 40.58451048843331,
		readU8() / 40.58451048843331,
		readU8() / 40.58451048843331
	) + Vector3.new(readF32(), readF32(), readF32())
end
writeFunctions.CFrameF32U8 = function(value: CFrame)
	local rotationX, rotationY, rotationZ = value:ToEulerAnglesXYZ()
	allocateBytes(15)
	writeU8(rotationX * 40.58451048843331 + 0.5)
	writeU8(rotationY * 40.58451048843331 + 0.5)
	writeU8(rotationZ * 40.58451048843331 + 0.5)
	writeF32(value.X)
	writeF32(value.Y)
	writeF32(value.Z)
end

typeSpecifiers.CFrameF32U16 = ("CFrameF32U16" :: any) :: CFrame
readFunctions.CFrameF32U16 = function()
	return CFrame.fromEulerAnglesXYZ(
		readU16() / 10430.219195527361,
		readU16() / 10430.219195527361,
		readU16() / 10430.219195527361
	) + Vector3.new(readF32(), readF32(), readF32())
end
writeFunctions.CFrameF32U16 = function(value: CFrame)
	local rotationX, rotationY, rotationZ = value:ToEulerAnglesXYZ()
	allocateBytes(18)
	writeU16(rotationX * 10430.219195527361 + 0.5)
	writeU16(rotationY * 10430.219195527361 + 0.5)
	writeU16(rotationZ * 10430.219195527361 + 0.5)
	writeF32(value.X)
	writeF32(value.Y)
	writeF32(value.Z)
end

--// Compound Type Serializers
typeSpecifiers.Region3 = ("Region3" :: any) :: Region3
readFunctions.Region3 = function()
	return Region3.new(Vector3.new(readF32(), readF32(), readF32()), Vector3.new(readF32(), readF32(), readF32()))
end
writeFunctions.Region3 = function(value: Region3)
	local halfSize = value.Size / 2
	local minimum = value.CFrame.Position - halfSize
	local maximum = value.CFrame.Position + halfSize
	allocateBytes(24)
	writeF32(minimum.X)
	writeF32(minimum.Y)
	writeF32(minimum.Z)
	writeF32(maximum.X)
	writeF32(maximum.Y)
	writeF32(maximum.Z)
end

typeSpecifiers.NumberSequence = ("NumberSequence" :: any) :: NumberSequence
readFunctions.NumberSequence = function()
	local keypointCount = readU8()
	local keypoints = table.create(keypointCount)
	for keypointIndex = 1, keypointCount do
		keypoints[keypointIndex] = NumberSequenceKeypoint.new(readU8() / 255, readU8() / 255, readU8() / 255)
	end
	return NumberSequence.new(keypoints)
end
writeFunctions.NumberSequence = function(value: NumberSequence)
	local keypointCount = #value.Keypoints
	allocateBytes(1 + keypointCount * 3)
	writeU8(keypointCount)
	for _, keypoint in value.Keypoints do
		writeU8(keypoint.Time * 255 + 0.5)
		writeU8(keypoint.Value * 255 + 0.5)
		writeU8(keypoint.Envelope * 255 + 0.5)
	end
end

typeSpecifiers.ColorSequence = ("ColorSequence" :: any) :: ColorSequence
readFunctions.ColorSequence = function()
	local keypointCount = readU8()
	local keypoints = table.create(keypointCount)
	for keypointIndex = 1, keypointCount do
		keypoints[keypointIndex] =
			ColorSequenceKeypoint.new(readU8() / 255, Color3.fromRGB(readU8(), readU8(), readU8()))
	end
	return ColorSequence.new(keypoints)
end
writeFunctions.ColorSequence = function(value: ColorSequence)
	local keypointCount = #value.Keypoints
	allocateBytes(1 + keypointCount * 4)
	writeU8(keypointCount)
	for _, keypoint in value.Keypoints do
		writeU8(keypoint.Time * 255 + 0.5)
		writeU8(keypoint.Value.R * 255 + 0.5)
		writeU8(keypoint.Value.G * 255 + 0.5)
		writeU8(keypoint.Value.B * 255 + 0.5)
	end
end

--// Characters Serializer
local characterIndicesByCharacter = {}
local charactersByIndex = require(script.Characters)
for characterIndex, character in charactersByIndex do
	characterIndicesByCharacter[character] = characterIndex
end
local bitsPerCharacter = math.ceil(math.log(#charactersByIndex + 1, 2))
local bytesPerCharacter = bitsPerCharacter / 8

typeSpecifiers.Characters = ("Characters" :: any) :: string
readFunctions.Characters = function()
	local characterCount = readU8()
	local characterArray = table.create(characterCount)
	local bitOffset = bufferOffset * 8
	bufferOffset += math.ceil(characterCount * bytesPerCharacter)
	for characterIndex = 1, characterCount do
		characterArray[characterIndex] = charactersByIndex[bufferReadBits(activeBuffer, bitOffset, bitsPerCharacter)]
		bitOffset += bitsPerCharacter
	end
	return table.concat(characterArray)
end
writeFunctions.Characters = function(value: string)
	local characterCount = #value
	local byteCount = math.ceil(characterCount * bytesPerCharacter)
	allocateBytes(1 + byteCount)
	writeU8(characterCount)
	local bitOffset = bufferOffset * 8
	for characterIndex = 1, characterCount do
		bufferWriteBits(
			activeBuffer,
			bitOffset,
			bitsPerCharacter,
			characterIndicesByCharacter[value:sub(characterIndex, characterIndex)]
		)
		bitOffset += bitsPerCharacter
	end
	bufferOffset += byteCount
end

--// Enum Serializer
local enumIndicesByEnumType = {}
local enumTypes = require(script.Enums)
for enumIndex, enumType in enumTypes do
	enumIndicesByEnumType[enumType] = enumIndex
end

typeSpecifiers.EnumItem = ("EnumItem" :: any) :: EnumItem
readFunctions.EnumItem = function()
	return enumTypes[readU8()]:FromValue(readU16())
end
writeFunctions.EnumItem = function(value: EnumItem)
	allocateBytes(3)
	writeU8(enumIndicesByEnumType[value.EnumType])
	writeU16(value.Value)
end

--// Static Value Serializers
local static1IndicesByValue = {}
local static1Values = require(script.Static1)
for valueIndex, staticValue in static1Values do
	static1IndicesByValue[staticValue] = valueIndex
end
typeSpecifiers.Static1 = ("Static1" :: any) :: any
readFunctions.Static1 = function()
	return static1Values[readU8()]
end
writeFunctions.Static1 = function(value: any)
	allocateBytes(1)
	writeU8(static1IndicesByValue[value] or 0)
end

local static2IndicesByValue = {}
local static2Values = require(script.Static2)
for valueIndex, staticValue in static2Values do
	static2IndicesByValue[staticValue] = valueIndex
end
typeSpecifiers.Static2 = ("Static2" :: any) :: any
readFunctions.Static2 = function()
	return static2Values[readU8()]
end
writeFunctions.Static2 = function(value: any)
	allocateBytes(1)
	writeU8(static2IndicesByValue[value] or 0)
end

local static3IndicesByValue = {}
local static3Values = require(script.Static3)
for valueIndex, staticValue in static3Values do
	static3IndicesByValue[staticValue] = valueIndex
end
typeSpecifiers.Static3 = ("Static3" :: any) :: any
readFunctions.Static3 = function()
	return static3Values[readU8()]
end
writeFunctions.Static3 = function(value: any)
	allocateBytes(1)
	writeU8(static3IndicesByValue[value] or 0)
end

--// Dynamic Type Serializers (Any)
anyReadFunctions[0] = function()
	return nil
end
anyWriteFunctions["nil"] = function(_value: nil)
	allocateBytes(1)
	writeU8(0)
end

anyReadFunctions[1] = function()
	return -readU8()
end
anyReadFunctions[2] = function()
	return -readU16()
end
anyReadFunctions[3] = function()
	return -readU24()
end
anyReadFunctions[4] = function()
	return -readU32()
end
anyReadFunctions[5] = function()
	return readU8()
end
anyReadFunctions[6] = function()
	return readU16()
end
anyReadFunctions[7] = function()
	return readU24()
end
anyReadFunctions[8] = function()
	return readU32()
end
anyReadFunctions[9] = function()
	return readF32()
end
anyReadFunctions[10] = function()
	return readF64()
end
anyWriteFunctions.number = function(value: number)
	if value % 1 == 0 then
		if value < 0 then
			if value > -256 then
				allocateBytes(2)
				writeU8(1)
				writeU8(-value)
			elseif value > -65536 then
				allocateBytes(3)
				writeU8(2)
				writeU16(-value)
			elseif value > -16777216 then
				allocateBytes(4)
				writeU8(3)
				writeU24(-value)
			elseif value > -4294967296 then
				allocateBytes(5)
				writeU8(4)
				writeU32(-value)
			else
				allocateBytes(9)
				writeU8(10)
				writeF64(value)
			end
		else
			if value < 256 then
				allocateBytes(2)
				writeU8(5)
				writeU8(value)
			elseif value < 65536 then
				allocateBytes(3)
				writeU8(6)
				writeU16(value)
			elseif value < 16777216 then
				allocateBytes(4)
				writeU8(7)
				writeU24(value)
			elseif value < 4294967296 then
				allocateBytes(5)
				writeU8(8)
				writeU32(value)
			else
				allocateBytes(9)
				writeU8(10)
				writeF64(value)
			end
		end
	elseif value > -1048576 and value < 1048576 then
		allocateBytes(5)
		writeU8(9)
		writeF32(value)
	else
		allocateBytes(9)
		writeU8(10)
		writeF64(value)
	end
end

anyReadFunctions[11] = function()
	return readStringFromBuffer(readU8())
end
anyWriteFunctions.string = function(value: string)
	local length = #value
	allocateBytes(2 + length)
	writeU8(11)
	writeU8(length)
	writeStringToBuffer(value)
end

anyReadFunctions[12] = function()
	return readBufferFromBuffer(readU8())
end
anyWriteFunctions.buffer = function(value: buffer)
	local length = buffer.len(value)
	allocateBytes(2 + length)
	writeU8(12)
	writeU8(length)
	writeBufferToBuffer(value)
end

anyReadFunctions[13] = function()
	return readInstance()
end
anyWriteFunctions.Instance = function(value: Instance)
	allocateBytes(1)
	writeU8(13)
	writeInstance(value)
end

anyReadFunctions[14] = function()
	return readU8() == 1
end
anyWriteFunctions.boolean = function(value: boolean)
	allocateBytes(2)
	writeU8(14)
	writeU8(if value then 1 else 0)
end

anyReadFunctions[15] = function()
	return NumberRange.new(readF32(), readF32())
end
anyWriteFunctions.NumberRange = function(value: NumberRange)
	allocateBytes(9)
	writeU8(15)
	writeF32(value.Min)
	writeF32(value.Max)
end

anyReadFunctions[16] = function()
	return BrickColor.new(readU16())
end
anyWriteFunctions.BrickColor = function(value: BrickColor)
	allocateBytes(3)
	writeU8(16)
	writeU16(value.Number)
end

anyReadFunctions[17] = function()
	return Color3.fromRGB(readU8(), readU8(), readU8())
end
anyWriteFunctions.Color3 = function(value: Color3)
	allocateBytes(4)
	writeU8(17)
	writeU8(value.R * 255 + 0.5)
	writeU8(value.G * 255 + 0.5)
	writeU8(value.B * 255 + 0.5)
end

anyReadFunctions[18] = function()
	return UDim.new(readS16() / 1000, readS16())
end
anyWriteFunctions.UDim = function(value: UDim)
	allocateBytes(5)
	writeU8(18)
	writeS16(value.Scale * 1000)
	writeS16(value.Offset)
end

anyReadFunctions[19] = function()
	return UDim2.new(readS16() / 1000, readS16(), readS16() / 1000, readS16())
end
anyWriteFunctions.UDim2 = function(value: UDim2)
	allocateBytes(9)
	writeU8(19)
	writeS16(value.X.Scale * 1000)
	writeS16(value.X.Offset)
	writeS16(value.Y.Scale * 1000)
	writeS16(value.Y.Offset)
end

anyReadFunctions[20] = function()
	return Rect.new(readF32(), readF32(), readF32(), readF32())
end
anyWriteFunctions.Rect = function(value: Rect)
	allocateBytes(17)
	writeU8(20)
	writeF32(value.Min.X)
	writeF32(value.Min.Y)
	writeF32(value.Max.X)
	writeF32(value.Max.Y)
end

anyReadFunctions[21] = function()
	return Vector2.new(readF32(), readF32())
end
anyWriteFunctions.Vector2 = function(value: Vector2)
	allocateBytes(9)
	writeU8(21)
	writeF32(value.X)
	writeF32(value.Y)
end

anyReadFunctions[22] = function()
	return Vector3.new(readF32(), readF32(), readF32())
end
anyWriteFunctions.Vector3 = function(value: Vector3)
	allocateBytes(13)
	writeU8(22)
	writeF32(value.X)
	writeF32(value.Y)
	writeF32(value.Z)
end

anyReadFunctions[23] = function()
	return CFrame.fromEulerAnglesXYZ(
		readU16() / 10430.219195527361,
		readU16() / 10430.219195527361,
		readU16() / 10430.219195527361
	) + Vector3.new(readF32(), readF32(), readF32())
end
anyWriteFunctions.CFrame = function(value: CFrame)
	local rotationX, rotationY, rotationZ = value:ToEulerAnglesXYZ()
	allocateBytes(19)
	writeU8(23)
	writeU16(rotationX * 10430.219195527361 + 0.5)
	writeU16(rotationY * 10430.219195527361 + 0.5)
	writeU16(rotationZ * 10430.219195527361 + 0.5)
	writeF32(value.X)
	writeF32(value.Y)
	writeF32(value.Z)
end

anyReadFunctions[24] = function()
	return Region3.new(Vector3.new(readF32(), readF32(), readF32()), Vector3.new(readF32(), readF32(), readF32()))
end
anyWriteFunctions.Region3 = function(value: Region3)
	local halfSize = value.Size / 2
	local minimum = value.CFrame.Position - halfSize
	local maximum = value.CFrame.Position + halfSize
	allocateBytes(25)
	writeU8(24)
	writeF32(minimum.X)
	writeF32(minimum.Y)
	writeF32(minimum.Z)
	writeF32(maximum.X)
	writeF32(maximum.Y)
	writeF32(maximum.Z)
end

anyReadFunctions[25] = function()
	local keypointCount = readU8()
	local keypoints = table.create(keypointCount)
	for keypointIndex = 1, keypointCount do
		keypoints[keypointIndex] = NumberSequenceKeypoint.new(readU8() / 255, readU8() / 255, readU8() / 255)
	end
	return NumberSequence.new(keypoints)
end
anyWriteFunctions.NumberSequence = function(value: NumberSequence)
	local keypointCount = #value.Keypoints
	allocateBytes(2 + keypointCount * 3)
	writeU8(25)
	writeU8(keypointCount)
	for _, keypoint in value.Keypoints do
		writeU8(keypoint.Time * 255 + 0.5)
		writeU8(keypoint.Value * 255 + 0.5)
		writeU8(keypoint.Envelope * 255 + 0.5)
	end
end

anyReadFunctions[26] = function()
	local keypointCount = readU8()
	local keypoints = table.create(keypointCount)
	for keypointIndex = 1, keypointCount do
		keypoints[keypointIndex] =
			ColorSequenceKeypoint.new(readU8() / 255, Color3.fromRGB(readU8(), readU8(), readU8()))
	end
	return ColorSequence.new(keypoints)
end
anyWriteFunctions.ColorSequence = function(value: ColorSequence)
	local keypointCount = #value.Keypoints
	allocateBytes(2 + keypointCount * 4)
	writeU8(26)
	writeU8(keypointCount)
	for _, keypoint in value.Keypoints do
		writeU8(keypoint.Time * 255 + 0.5)
		writeU8(keypoint.Value.R * 255 + 0.5)
		writeU8(keypoint.Value.G * 255 + 0.5)
		writeU8(keypoint.Value.B * 255 + 0.5)
	end
end

anyReadFunctions[27] = function()
	return enumTypes[readU8()]:FromValue(readU16())
end
anyWriteFunctions.EnumItem = function(value: EnumItem)
	allocateBytes(4)
	writeU8(27)
	writeU8(enumIndicesByEnumType[value.EnumType])
	writeU16(value.Value)
end

anyReadFunctions[28] = function()
	local deserializedTable = {}
	while true do
		local typeId = readU8()
		if typeId == 0 then
			return deserializedTable
		else
			deserializedTable[anyReadFunctions[typeId]()] = anyReadFunctions[readU8()]()
		end
	end
end
anyWriteFunctions.table = function(value: { [any]: any })
	allocateBytes(1)
	writeU8(28)
	for tableKey, tableValue in value do
		anyWriteFunctions[typeof(tableKey)](tableKey)
		anyWriteFunctions[typeof(tableValue)](tableValue)
	end
	allocateBytes(1)
	writeU8(0)
end

--// Module Export
return {
	Import = function(cursor: Cursor)
		activeCursor = cursor
		activeBuffer = cursor.Buffer
		bufferLength = cursor.BufferLength
		bufferOffset = cursor.BufferOffset
		activeInstances = cursor.Instances
		instancesOffset = cursor.InstancesOffset
	end,

	Export = function()
		activeCursor.BufferLength = bufferLength
		activeCursor.BufferOffset = bufferOffset
		activeCursor.InstancesOffset = instancesOffset
		return activeCursor
	end,

	Truncate = function()
		local truncatedBuffer = buffer.create(bufferOffset)
		buffer.copy(truncatedBuffer, 0, activeBuffer, 0, bufferOffset)
		if instancesOffset == 0 then
			return truncatedBuffer
		else
			return truncatedBuffer, activeInstances
		end
	end,

	Ended = function()
		return bufferOffset >= bufferLength
	end,

	Types = typeSpecifiers,
	ReadFunctions = readFunctions,
	WriteFunctions = writeFunctions,
}
