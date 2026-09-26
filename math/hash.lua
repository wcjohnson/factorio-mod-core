-- Hash algorithm support code.

local band = bit32.band
local bor = bit32.bor
local bxor = bit32.bxor
local blshift = bit32.lshift
local brshift = bit32.rshift
local lrotate = bit32.lrotate
local strbyte = string.byte
local U32_MASK = 0xFFFFFFFF
local U16_MASK = 0xFFFF

local lib = {}

function lib.jenkins_mix_u32(hash, byte)
	hash = band(hash + byte, U32_MASK)
	hash = band(hash + blshift(hash, 10), U32_MASK)
	hash = bxor(hash, brshift(hash, 6))
	return hash
end

function lib.jenkins_finalize_u32(hash)
	hash = band(hash + blshift(hash, 3), U32_MASK)
	hash = bxor(hash, brshift(hash, 11))
	hash = band(hash + blshift(hash, 15), U32_MASK)
	return hash
end

function lib.djb2_mix_u32(hash, byte)
	hash = band(blshift(hash, 5) + hash, U32_MASK)
	hash = bxor(hash, byte)
	return hash
end

local function multiply_u32(a, b)
	local low = band(a, U16_MASK) * band(b, U16_MASK)
	local cross = brshift(a, 16) * band(b, U16_MASK)
		+ band(a, U16_MASK) * brshift(b, 16)
	return band(low + blshift(cross, 16), U32_MASK)
end

---@param value string
---@param seed uint32?
---@return uint32
function lib.murmur3_32(value, seed)
	local hash = seed or 0
	local length = #value
	local block_end = length - (length % 4)

	for i = 1, block_end, 4 do
		local block = strbyte(value, i)
			+ blshift(strbyte(value, i + 1), 8)
			+ blshift(strbyte(value, i + 2), 16)
			+ blshift(strbyte(value, i + 3), 24)
		block = multiply_u32(block, 0xCC9E2D51)
		block = lrotate(block, 15)
		block = multiply_u32(block, 0x1B873593)

		hash = bxor(hash, block)
		hash = lrotate(hash, 13)
		hash = band(multiply_u32(hash, 5) + 0xE6546B64, U32_MASK)
	end

	local tail = 0
	local remaining = length % 4
	if remaining >= 3 then tail = blshift(strbyte(value, block_end + 3), 16) end
	if remaining >= 2 then
		tail = bor(tail, blshift(strbyte(value, block_end + 2), 8))
	end
	if remaining >= 1 then
		tail = bor(tail, strbyte(value, block_end + 1))
		tail = multiply_u32(tail, 0xCC9E2D51)
		tail = lrotate(tail, 15)
		tail = multiply_u32(tail, 0x1B873593)
		hash = bxor(hash, tail)
	end

	hash = bxor(hash, length)
	hash = bxor(hash, brshift(hash, 16))
	hash = multiply_u32(hash, 0x85EBCA6B)
	hash = bxor(hash, brshift(hash, 13))
	hash = multiply_u32(hash, 0xC2B2AE35)
	return bxor(hash, brshift(hash, 16))
end

return lib
