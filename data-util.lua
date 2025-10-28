-- Data phase utilities

local lib = {}

--- Copy a prototype, assigning a new name and minable properties.
--- This code comes from flib.
--- @param prototype table
--- @param new_name string string
--- @param remove_icon? boolean
--- @return table
function lib.copy_prototype(prototype, new_name, remove_icon)
	if not prototype.type or not prototype.name then
		error("Invalid prototype: prototypes must have name and type properties.")
		return --- @diagnostic disable-line
	end
	local p = table.deepcopy(prototype)
	p.name = new_name
	if p.minable and p.minable.result then p.minable.result = new_name end
	if p.place_result then p.place_result = new_name end
	if p.result then p.result = new_name end
	if p.results then
		for _, result in pairs(p.results) do
			if result.name == prototype.name then result.name = new_name end
		end
	end
	if remove_icon then
		p.icon = nil
		p.icon_size = nil
		p.icons = nil
	end

	return p
end

return lib
