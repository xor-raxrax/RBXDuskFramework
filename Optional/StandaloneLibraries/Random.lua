local function randomFrom2Ranges(range1Start, range1End, range2Start, range2End)
	local range1Size = range1End - range1Start + 1
	local range2Size = range2End - range2Start + 1

	local sum = range1Size + range2Size

	local randomSum = math.random(sum)

	if randomSum <= range1Size then
		return range1Start + randomSum - 1
	else
		return range2Start + (randomSum - range1Size) - 1
	end
end

local function randomBinaryString(size)
	local result = ""
	for _ = 1, size do
		result ..= string.char(math.random(0, 255))
	end
	return result
end

local function randomBinaryNonZeroString(size)
	local result = ""
	for _ = 1, size do
		result ..= string.char(math.random(1, 255))
	end
	return result
end

local function randomAlphaString(size)
	local result = ""
	for i = 1, size do
		result ..= string.char(randomFrom2Ranges(
			65, 90, -- A - Z
			97, 122 -- a - z
		))
	end
	return result
end

local random

local function randomNameSize()
	return math.random(random.NAME_SIZE_MIN, random.NAME_SIZE_MAX)
end

local function randomInstanceName()
	return randomAlphaString(randomNameSize())
end

random = {}

random.NAME_SIZE_MIN = 10
random.NAME_SIZE_MAX = 20
random.randomFrom2Ranges = randomFrom2Ranges
random.randomBinaryString = randomBinaryString
random.randomBinaryNonZeroString = randomBinaryNonZeroString
random.randomAlphaString = randomAlphaString
random.randomNameSize = randomNameSize
random.randomInstanceName = randomInstanceName

return random