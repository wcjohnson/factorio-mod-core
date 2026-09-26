-- Base64 encoding support code.

local band = bit32.band
local brshift = bit32.rshift
local strsub = string.sub
local concat = table.concat

local lib = {}

local BASE64 =
	"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

---@param value uint32
---@return string
function lib.encode_u32(value)
	return concat({
		strsub(BASE64, brshift(value, 26) + 1, brshift(value, 26) + 1),
		strsub(
			BASE64,
			band(brshift(value, 20), 0x3F) + 1,
			band(brshift(value, 20), 0x3F) + 1
		),
		strsub(
			BASE64,
			band(brshift(value, 14), 0x3F) + 1,
			band(brshift(value, 14), 0x3F) + 1
		),
		strsub(
			BASE64,
			band(brshift(value, 8), 0x3F) + 1,
			band(brshift(value, 8), 0x3F) + 1
		),
		strsub(
			BASE64,
			band(brshift(value, 2), 0x3F) + 1,
			band(brshift(value, 2), 0x3F) + 1
		),
		strsub(BASE64, band(value, 0x03) * 16 + 1, band(value, 0x03) * 16 + 1),
		"==",
	})
end

---@param high uint32
---@param low uint32
---@return string
function lib.encode_u64(high, low)
	return concat({
		strsub(BASE64, brshift(high, 26) + 1, brshift(high, 26) + 1),
		strsub(
			BASE64,
			band(brshift(high, 20), 0x3F) + 1,
			band(brshift(high, 20), 0x3F) + 1
		),
		strsub(
			BASE64,
			band(brshift(high, 14), 0x3F) + 1,
			band(brshift(high, 14), 0x3F) + 1
		),
		strsub(
			BASE64,
			band(brshift(high, 8), 0x3F) + 1,
			band(brshift(high, 8), 0x3F) + 1
		),
		strsub(
			BASE64,
			band(brshift(high, 2), 0x3F) + 1,
			band(brshift(high, 2), 0x3F) + 1
		),
		strsub(
			BASE64,
			(band(high, 0x03) * 16 + brshift(low, 28)) + 1,
			(band(high, 0x03) * 16 + brshift(low, 28)) + 1
		),
		strsub(
			BASE64,
			band(brshift(low, 22), 0x3F) + 1,
			band(brshift(low, 22), 0x3F) + 1
		),
		strsub(
			BASE64,
			band(brshift(low, 16), 0x3F) + 1,
			band(brshift(low, 16), 0x3F) + 1
		),
		strsub(
			BASE64,
			band(brshift(low, 10), 0x3F) + 1,
			band(brshift(low, 10), 0x3F) + 1
		),
		strsub(
			BASE64,
			band(brshift(low, 4), 0x3F) + 1,
			band(brshift(low, 4), 0x3F) + 1
		),
		strsub(BASE64, band(low, 0x0F) * 4 + 1, band(low, 0x0F) * 4 + 1),
		"=",
	})
end

return lib
