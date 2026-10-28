--------------------------------------------------------------------------------
-- Nested Sparse 2D matrix.
--------------------------------------------------------------------------------

local next = next

local lib = {}

---@alias Sparse2DNested<T> table<number, table<number, T>>

---@generic T
---@param M Sparse2DNested<T>
---@param x number
---@param y number
---@return T
local function get(M, x, y)
	local row = M[x]
	if not row then return nil end
	return row[y]
end
lib.get = get

---Get a value from a symmetric sparse 2D matrix.
---@generic T
---@param M Sparse2DNested<T>
---@param x number
---@param y number
---@return T
function lib.get_symmetric(M, x, y)
	if x > y then
		x, y = y, x
	end
	return get(M, x, y)
end

---@generic T
---@param M Sparse2DNested<T>
---@param x number
---@param y number
---@param value T?
---@return Sparse2DNested<T> M The original input matrix.
local function set(M, x, y, value)
	local row = M[x]
	if not row then
		row = {}
		M[x] = row
	end
	row[y] = value
	if not next(row) then M[x] = nil end
	return M
end
lib.set = set

---Set a value in a symmetric sparse 2D matrix.
---@generic T
---@param M Sparse2DNested<T>
---@param x number
---@param y number
---@param value T?
---@return Sparse2DNested<T> M The original input matrix.
local function set_symmetric(M, x, y, value)
	if x > y then
		x, y = y, x
	end
	return set(M, x, y, value)
end
lib.set_symmetric = set_symmetric

return lib
