-- Generic and simplistic debug logging facility.

local print_debug_log = false

---Log all arguments to the debug log. Also logs using `game.print` if
---`print_debug_log` is set. Arguments are automatically stringified by
---`serpent.line`.
---@param ... any
local function debug_log(...)
	local x = table.pack(...)
	x.n = nil
	if #x == 1 then x = x[1] end
	local line = serpent.line(x, { nocode = true })
	if print_debug_log and game then
		game.print(line, {
			skip = defines.print_skip.never,
			sound = defines.print_sound.never,
			game_state = false,
		})
	end
	log(line)
end
_G.debug_log = debug_log

---@param v boolean
local function set_print_debug_log(v) print_debug_log = v end
_G.set_print_debug_log = set_print_debug_log
