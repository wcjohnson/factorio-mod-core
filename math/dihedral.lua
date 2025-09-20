-- Dihedral group operations for 2D rotations and flips.

local lib = {}

local function t_pack(...) return { ... } end

---Tuple describing an element `r^n * s^m` of a dihedral group.
---`X[1]` indicates the order of `r` in the group. (half the order of the group)
---`X[2]` indicates the power of `r` in the element (i.e. the number of rotations to apply)
---`X[3]` indicates the power of `s` in the element (0 for no reflection, 1 for reflection).
---@alias Core.Dihedral [integer, integer, 0|1]

---Check equality of two dihedral group elements in exploded form.
---@param x1 integer
---@param x2 integer
---@param x3 0|1
---@param y1 integer
---@param y2 integer
---@param y3 0|1
local function exploded_eq(x1, x2, x3, y1, y2, y3)
	return x1 == y1 and x2 == y2 and x3 == y3
end
lib.exploded_eq = exploded_eq

---Check equality of two dihedral group elements.
---@param A Core.Dihedral
---@param B Core.Dihedral
---@return boolean
local function eq(A, B) return exploded_eq(A[1], A[2], A[3], B[1], B[2], B[3]) end
lib.eq = eq

---Invert a dihedral group element in exploded form.
---@param x1 integer
---@param x2 integer
---@param x3 0|1
---@return integer, integer, 0|1
local function exploded_invert(x1, x2, x3)
	if x3 == 0 then
		return x1, (x1 - x2) % x1, x3
	else
		return x1, x2, x3
	end
end
lib.exploded_invert = exploded_invert

---Invert a dihedral group element.
---@param x Core.Dihedral
---@return Core.Dihedral
function lib.invert(x) return t_pack(exploded_invert(x[1], x[2], x[3])) end

---Compose two dihedral group elements in exploded form.
---@param x1 integer
---@param x2 integer
---@param x3 0|1
---@param y1 integer
---@param y2 integer
---@param y3 0|1
---@return integer, integer, 0|1
local function exploded_product(x1, x2, x3, y1, y2, y3)
	if x1 ~= y1 then error("Mismatched dihedral group orders") end
	if x3 == 0 and y3 == 0 then
		-- r^a * r^b = r^(a+b)
		return x1, (x2 + y2) % x1, 0
	elseif x3 == 0 and y3 == 1 then
		-- r^a * r^b * s = r^(a+b) * s
		return x1, (x2 + y2) % x1, 1
	elseif x3 == 1 and y3 == 0 then
		-- r^a * s * r^b = r^(a-b) * s
		return x1, (x2 - y2) % x1, 1
	elseif x3 == 1 and y3 == 1 then
		-- r^a * s * r^b * s = r^(a-b)
		return x1, (x2 - y2) % x1, 0
	else
		error("Invalid dihedral group element")
	end
end
lib.exploded_product = exploded_product

---Compose dihedral group elements.
---@param A Core.Dihedral
---@param ... Core.Dihedral[]
---@return Core.Dihedral
function lib.product(A, ...)
	local x1, x2, x3 = A[1], A[2], A[3]
	for i = 1, select("#", ...) do
		local B = select(i, ...)
		x1, x2, x3 = exploded_product(x1, x2, x3, B[1], B[2], B[3])
	end
	return { x1, x2, x3 }
end

return lib
