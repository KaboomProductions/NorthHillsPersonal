local characterReplication = {}

characterReplication.packetKinds = {
	body = "body",
	shoulders = "shoulders",
}

local fieldOrder: { [string]: { string } } = {
	body = { "neckC0", "rootC0", "leftHipC0", "rightHipC0" },
	shoulders = { "leftShoulderC0", "rightShoulderC0" },
}

local kindBit: { [string]: number } = {
	body = 0,
	shoulders = 1,
}

local bitToKind: { [number]: string } = {
	[0] = "body",
	[1] = "shoulders",
}

characterReplication.maximumAbsolutePosition = 64
characterReplication.maximumAbsoluteAngle = math.pi * 2
characterReplication.transformComponentCount = 6

local int16Max = 32767
local int16Min = -32767

local positionScale = int16Max / characterReplication.maximumAbsolutePosition
local angleScale = int16Max / characterReplication.maximumAbsoluteAngle

local headerSize = 5
local fieldByteSize = 12

local forceSendBitMask = 0x02
local fieldBitsShift = 2

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function quantizeComponent(value: number, scale: number): number
	return math.clamp(math.round(value * scale), int16Min, int16Max)
end

local function quantizeCFrame(cframe: CFrame): { number }
	local position = cframe.Position
	local rx, ry, rz = cframe:ToOrientation()

	return {
		quantizeComponent(position.X, positionScale),
		quantizeComponent(position.Y, positionScale),
		quantizeComponent(position.Z, positionScale),
		quantizeComponent(rx, angleScale),
		quantizeComponent(ry, angleScale),
		quantizeComponent(rz, angleScale),
	}
end

local function quantizedCFramesEqual(left: { number }?, right: { number }?): boolean
	if left == nil or right == nil then
		return left == right
	end

	for componentIndex = 1, characterReplication.transformComponentCount do
		if left[componentIndex] ~= right[componentIndex] then
			return false
		end
	end

	return true
end

local function writeQuantizedCFrame(targetBuffer: buffer, byteOffset: number, quantized: { number })
	buffer.writei16(targetBuffer, byteOffset, quantized[1])
	buffer.writei16(targetBuffer, byteOffset + 2, quantized[2])
	buffer.writei16(targetBuffer, byteOffset + 4, quantized[3])
	buffer.writei16(targetBuffer, byteOffset + 6, quantized[4])
	buffer.writei16(targetBuffer, byteOffset + 8, quantized[5])
	buffer.writei16(targetBuffer, byteOffset + 10, quantized[6])
end

local function readCFrame(sourceBuffer: buffer, byteOffset: number): CFrame
	local px = buffer.readi16(sourceBuffer, byteOffset) / positionScale
	local py = buffer.readi16(sourceBuffer, byteOffset + 2) / positionScale
	local pz = buffer.readi16(sourceBuffer, byteOffset + 4) / positionScale
	local rx = buffer.readi16(sourceBuffer, byteOffset + 6) / angleScale
	local ry = buffer.readi16(sourceBuffer, byteOffset + 8) / angleScale
	local rz = buffer.readi16(sourceBuffer, byteOffset + 10) / angleScale

	return CFrame.new(px, py, pz) * CFrame.fromOrientation(rx, ry, rz)
end

local function buildQuantizedFieldMap(
	orderedFieldNames: { string },
	cframes: { [string]: CFrame? }
): { [string]: { number } }
	local quantizedFieldMap = {}

	for _, fieldName in ipairs(orderedFieldNames) do
		local cframe = cframes[fieldName]
		if cframe ~= nil then
			quantizedFieldMap[fieldName] = quantizeCFrame(cframe)
		end
	end

	return quantizedFieldMap
end

local function getChangedFieldNames(
	orderedFieldNames: { string },
	currentFieldMap: { [string]: { number } },
	lastFieldMap: { [string]: { number } }?
): { string }
	local changedFieldNames = {}

	for _, fieldName in ipairs(orderedFieldNames) do
		local current = currentFieldMap[fieldName]
		if current ~= nil then
			local last = if lastFieldMap then lastFieldMap[fieldName] else nil
			if not quantizedCFramesEqual(current, last) then
				table.insert(changedFieldNames, fieldName)
			end
		end
	end

	return changedFieldNames
end

local function buildPacketBuffer(
	kind: string,
	sequence: number,
	orderedFieldNames: { string },
	quantizedFieldMap: { [string]: { number } },
	changedFieldNames: { string },
	forceSend: boolean?
): buffer
	local fieldBits = 0
	for bitIndex, fieldName in ipairs(orderedFieldNames) do
		if table.find(changedFieldNames, fieldName) ~= nil then
			fieldBits = bit32.bor(fieldBits, bit32.lshift(1, bitIndex - 1))
		end
	end

	local flags = kindBit[kind]
	if forceSend == true then
		flags = bit32.bor(flags, forceSendBitMask)
	end
	flags = bit32.bor(flags, bit32.lshift(fieldBits, fieldBitsShift))

	local packetBuffer = buffer.create(headerSize + fieldByteSize * #changedFieldNames)
	buffer.writeu8(packetBuffer, 0, flags)
	buffer.writeu32(packetBuffer, 1, sequence)

	local writeOffset = headerSize
	for _, fieldName in ipairs(changedFieldNames) do
		writeQuantizedCFrame(packetBuffer, writeOffset, quantizedFieldMap[fieldName])
		writeOffset += fieldByteSize
	end

	return packetBuffer
end

local function buildPacket(
	kind: string,
	sequence: number,
	cframes: { [string]: CFrame? },
	lastQuantizedFieldMap: { [string]: { number } }?,
	forceSend: boolean?
): (buffer?, { [string]: { number } })
	local orderedFieldNames = fieldOrder[kind]
	local quantizedFieldMap = buildQuantizedFieldMap(orderedFieldNames, cframes)
	local changedFieldNames = getChangedFieldNames(orderedFieldNames, quantizedFieldMap, lastQuantizedFieldMap)

	if #changedFieldNames == 0 and forceSend ~= true then
		return nil, quantizedFieldMap
	end

	if #changedFieldNames == 0 and forceSend == true then
		changedFieldNames = {}
		for _, fieldName in ipairs(orderedFieldNames) do
			if quantizedFieldMap[fieldName] ~= nil then
				table.insert(changedFieldNames, fieldName)
			end
		end
	end

	local packetBuffer =
		buildPacketBuffer(kind, sequence, orderedFieldNames, quantizedFieldMap, changedFieldNames, forceSend)
	return packetBuffer, quantizedFieldMap
end

function characterReplication.createBodyPacket(
	sequence: number,
	bodyC0s: {
		neckC0: CFrame?,
		rootC0: CFrame?,
		leftHipC0: CFrame?,
		rightHipC0: CFrame?,
	},
	lastQuantizedFieldMap: { [string]: { number } }?,
	forceSend: boolean?
): (buffer?, { [string]: { number } })
	return buildPacket(characterReplication.packetKinds.body, sequence, bodyC0s, lastQuantizedFieldMap, forceSend)
end

function characterReplication.createShoulderPacket(
	sequence: number,
	shoulderC0s: { leftShoulderC0: CFrame?, rightShoulderC0: CFrame? },
	lastQuantizedFieldMap: { [string]: { number } }?,
	forceSend: boolean?
): (buffer?, { [string]: { number } })
	return buildPacket(
		characterReplication.packetKinds.shoulders,
		sequence,
		shoulderC0s,
		lastQuantizedFieldMap,
		forceSend
	)
end

function characterReplication.sanitizePacket(rawPacket: any): { k: string, s: number, f: boolean, buffer: buffer }?
	if type(rawPacket) ~= "buffer" then
		return nil
	end

	local packetLength = buffer.len(rawPacket)
	if packetLength < headerSize then
		return nil
	end

	local flags = buffer.readu8(rawPacket, 0)
	local trueKindBit = bit32.band(flags, 0x01)
	local forceSend = bit32.band(flags, forceSendBitMask) ~= 0
	local fieldBits = bit32.rshift(flags, fieldBitsShift)

	local kind = bitToKind[trueKindBit]
	if kind == nil then
		return nil
	end

	local orderedFieldNames = fieldOrder[kind]
	local maxFieldBits = bit32.lshift(1, #orderedFieldNames) - 1
	if bit32.band(fieldBits, bit32.bnot(maxFieldBits)) ~= 0 then
		return nil
	end

	if fieldBits == 0 then
		return nil
	end

	local presentFieldCount = 0
	for bitIndex = 1, #orderedFieldNames do
		if bit32.band(fieldBits, bit32.lshift(1, bitIndex - 1)) ~= 0 then
			presentFieldCount += 1
		end
	end

	local expectedLength = headerSize + fieldByteSize * presentFieldCount
	if packetLength ~= expectedLength then
		return nil
	end

	local sequence = buffer.readu32(rawPacket, 1)
	if not isFiniteNumber(sequence) then
		return nil
	end

	return {
		k = kind,
		s = sequence,
		f = forceSend,
		buffer = rawPacket,
	}
end

function characterReplication.decodePacket(rawPacket: any): (string?, number?, { [string]: CFrame }?)
	local sanitized = characterReplication.sanitizePacket(rawPacket)
	if sanitized == nil then
		return nil, nil, nil
	end

	local orderedFieldNames = fieldOrder[sanitized.k]
	local flags = buffer.readu8(sanitized.buffer, 0)
	local fieldBits = bit32.rshift(flags, fieldBitsShift)

	local decodedFieldMap = {}
	local readOffset = headerSize

	for bitIndex, fieldName in ipairs(orderedFieldNames) do
		if bit32.band(fieldBits, bit32.lshift(1, bitIndex - 1)) ~= 0 then
			decodedFieldMap[fieldName] = readCFrame(sanitized.buffer, readOffset)
			readOffset += fieldByteSize
		end
	end

	return sanitized.k, sanitized.s, decodedFieldMap
end

return characterReplication
