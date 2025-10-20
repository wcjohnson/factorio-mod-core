-- Generic and simplistic debug logging facility.

local strace = require("lib.core.strace")

local print_debug_log = false

---Log all arguments to the debug log. Also logs using `game.print` if
---`print_debug_log` is set. Arguments are automatically stringified by
---`serpent.line`.
---@param ... any
local function debug_log(...) return strace.debug(...) end
_G.debug_log = debug_log

---Crash with an error string containing all arguments stringified by `serpent.line`.
---@param ... any
local function debug_crash(...)
	local x = table.pack(...)
	x.n = nil
	if #x == 1 then x = x[1] end
	local line = serpent.line(x, { nocode = true })
	error(line)
end
_G.debug_crash = debug_crash

---@param v boolean
local function set_print_debug_log(v) print_debug_log = v end
_G.set_print_debug_log = set_print_debug_log
