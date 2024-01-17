local function pack2uint8(a, b)
	return (a * 2^8) + a
end

local function unpack2uint8(packed)
	local a = math.floor(packed / 2^8)
	local b = packed % 2^8
	return a, b
end

local function pack3uint8(a, b, c)
	return (a * 2^16) + (b * 2^8) + c
end

local function unpack3uint8(packed)
	local a = math.floor(packed / 2^16)
	local b = math.floor((packed % 2^16) / 2^8)
	local c = packed % 2^8
	return a, b, c
end

local function pack4uint8(a, b, c, d)
	return (a * 2^24) + (b * 2^16) + (c * 2^8) + d
end

local function unpack4uint8(packed)
	local a = math.floor(packed / 2^24)
	local b = math.floor((packed % 2^24) / 2^16)
	local c = math.floor((packed % 2^16) / 2^8)
	local d = packed % 2^8
	return a, b, c, d
end

local function pack2uint16(a, b)
	return (a * 2^16) + b
end

local function unpack2uint16(packed)
	local a = math.floor(packed / 2^16)
	local b = packed % 2^16
	return a, b
end

local function pack3uint16(a, b, c)
	return (a * 2^32) + (b * 2^16) + c
end

local function unpack3uint16(packed)
	local a = math.floor(packed / 2^32)
	local b = math.floor((packed % 2^32) / 2^16)
	local c = packed % 2^16
	return a, b, c
end

local function packcolor3(color)
	local r = math.floor(color.R * 255)
	local g = math.floor(color.G * 255)
	local b = math.floor(color.B * 255)
	return pack3uint8(r, g, b)
end

local function unpackcolor3(packed)
	return Color3.fromRGB(unpack3uint8(packed))
end

local function packvector2uint16(vector)
	return pack2uint16(vector.X, vector.Y)
end

local function unpackvector2uint16(packed)
	return Vector2int16.new(unpack2uint16(packed))
end

local function packvector3uint16(vector)
	return pack3uint16(vector.X, vector.Y, vector.Z)
end

local function unpackvector3uint16(packed)
	return Vector2int16.new(unpack3uint16(packed))
end

local numcast = {}

numcast.pack2uint16 = pack2uint16
numcast.pack3uint16 = pack3uint16

numcast.unpack2uint16 = unpack2uint16
numcast.unpack3uint16 = unpack3uint16

numcast.pack2uint8 = pack2uint8
numcast.pack3uint8 = pack3uint8
numcast.pack4uint8 = pack4uint8

numcast.unpack2uint8 = unpack2uint8
numcast.unpack3uint8 = unpack3uint8
numcast.unpack4uint8 = unpack4uint8

numcast.packvector2uint16 = packvector2uint16
numcast.packvector3uint16 = packvector3uint16
-- expects color channel value in range 0-1, otherwise it is UB
numcast.packcolor3 = packcolor3

numcast.unpackvector2uint16 = unpackvector2uint16
numcast.unpackvector3uint16 = unpackvector3uint16
numcast.unpackcolor3 = unpackcolor3

return numcast