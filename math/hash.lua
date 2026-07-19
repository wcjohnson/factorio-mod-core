-- Hash algorithm support code.

local band = bit32.band
local bxor = bit32.bxor
local blshift = bit32.lshift
local brshift = bit32.rshift
local U32_MASK = 0xFFFFFFFF

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

return lib
