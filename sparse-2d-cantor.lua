--------------------------------------------------------------------------------
-- Cantor Sparse 2D matrix.
--------------------------------------------------------------------------------

local lib = {}

-- Highest valid index for the Cantor pairing function. Indices higher than this cause floating point precision issues.
lib.INDEX_LIMIT = 67108863

---@alias Sparse2DCantor<T> table<number, T>

---@generic T
---@param M Sparse2DCantor<T>
---@param x number
---@param y number
---@return T
function lib.get(M, x, y)
	local x_plus_y = x + y
	local key = 0.5 * x_plus_y * (x_plus_y + 1) + y
	return M[key]
end

---@generic T
---@param M Sparse2DCantor<T>
---@param x number
---@param y number
---@param value T
---@return Sparse2DCantor<T> M The original input matrix.
function lib.set(M, x, y, value)
	local x_plus_y = x + y
	local key = 0.5 * x_plus_y * (x_plus_y + 1) + y
	M[key] = value
	return M
end

return lib
