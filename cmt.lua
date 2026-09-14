--- Cooperative multitasking library for Factorio mods.

local strace = require("lib.core.strace")
local class = require("lib.core.class").class
local nlib = require("lib.core.math.numeric")
local era_lib = require("lib.core.math.era-counter")
local tlib = require("lib.core.table")
local events = require("lib.core.event")
local counters = require("lib.core.counters")

local BIG_INT = nlib.BIG_INT
local max = math.max
local update_era_counter = era_lib.update_era_counter
local filter_in_place = tlib.filter_in_place
local pairs = pairs
local tinsert = table.insert
local tremove = table.remove

local REALTIME_WORK_CAP = BIG_INT / 2.0

---@class Core.CMT.Lib
local lib = {}

--------------------------------------------------------------------------------
-- Data
--------------------------------------------------------------------------------

---@alias Core.CMT.TaskID integer

---@alias Core.CMT.TaskSet { [Core.CMT.Task]: true }

---@class Core.CMT.Task
---@field public _cmt_id Core.CMT.TaskID The ID of the task
---@field public _cmt_awake boolean Whether the task is awake or sleeping
---@field public _cmt_dead? true Whether the task is dead and should be removed from the runqueue
---@field public _cmt_yielded? true Whether the task yielded during its last timeslice.
---@field public _cmt_spike_yielded? uint64 Tick on which the task spike yielded. The task will not run again on this tick.
---@field public _cmt_realtime? boolean Whether the task is realtime (runs every tick) or not (runs round-robin)
---@field public _cmt_tick_slept? uint The tick at which the task was put to sleep. If nil, the task is awake.
---@field public _cmt_tick_wake? uint The tick at which the task is scheduled to wake.
---@field public _cmt_name? string An optional friendly name for debugging purposes
---@field public _cmt_work_current number The amount of current sequential work done by this task.
---@field public _cmt_work_cap? number Maximum workload this task can consume sequentially. The task's main loop will be re-entered until this cap is reached. If not given, 0, or negative, the task will yield after each iteration of its main loop.
---@field public _cmt_work_per_iter Core.EraCounter ERA work per iteration of mainloop.
---@field public _cmt_debug_paused? boolean Whether the task is paused for debugging purposes
---@field public _cmt_debug_stepped? boolean Whether the task should execute one step while paused for debugging purposes
local Task = class("Core.CMT.Task")
lib.Task = Task

function Task:new()
	return setmetatable({
		_cmt_awake = false,
		_cmt_work_current = 0,
		_cmt_work_per_iter = era_lib.create_era_counter(0, 0.25),
	}, self)
end

---Task main loop.
---@return number workload The amount of work done by this task in this iteration. This is used to determine how much work has been done in the current frame and whether to yield to other tasks. Because actual timings are not accessible in Factorio, this is an empirical best-effort approximation.
function Task:main() return 0 end

---@class (exact) Core.CMT.Storage
---@field public tasks table<Core.CMT.TaskID, Core.CMT.Task> The set of all tasks
---@field public rq_realtime Core.CMT.Task[] The run queue of realtime tasks
---@field public rq_normal Core.CMT.Task[] The run queue of normal tasks
---@field public rq_normal_pointer uint The index of the next normal task to run
---@field public wake_at { [uint]: Core.CMT.TaskSet } The set of tasks scheduled to wake at a given tick
---@field public max_work_per_frame number Maximum amount of work to be done per frame across all tasks
---@field public spike_owner_id? Core.CMT.TaskID Normal task that will run after realtime tasks next frame with one spike-yield bypass

local function init_cmt_storage()
	strace.warn(
		"Initializing CMT storage. This should only happen once per game session."
	)
	---@type Core.CMT.Storage
	local data = {
		tasks = {},
		rq_realtime = {},
		wake_at = {},
		rq_normal = {},
		rq_normal_pointer = 1,
		max_work_per_frame = 100,
	}
	---@diagnostic disable-next-line: inject-field
	storage._cmt = data
	return data
end

---@return Core.CMT.Storage
local function get_cmt_storage()
	---@diagnostic disable-next-line: undefined-field
	local data = storage._cmt
	if not data then data = init_cmt_storage() end
	return data
end

--------------------------------------------------------------------------------
-- Task Core
--------------------------------------------------------------------------------

-- Transients
-- XXX: MP SAFETY: These are only used across one iteration of a mainloop and therefore cannot lose synchronization across a save boundary.

local running_task = nil
local running_work_done = 0.0
local running_work_cap = 0.0
local bypass_spike_yield = false
local running_as_spike_owner = false

---@param task Core.CMT.Task? Task at the head of the runqueue. If nil, the runqueue is empty.
---@param tick uint64 The current tick.
---@param frame_work_done number Work already completed by this runqueue.
---@param frame_work_cap number Maximum work for this runqueue.
---@return boolean advance `true` if we should advance the pointer to the next task
---@return boolean ran `true` if the task mainloop ran, `false` if task was sleeping, dead, or skipped.
---@return number work_done The amount of work done in this iteration.
local function runq_step_task(task, tick, frame_work_done, frame_work_cap)
	-- Check for nil, dead, sleeping
	if not task then return false, false, 0 end
	if task._cmt_dead or not task._cmt_awake then return true, false, 0 end
	if task._cmt_spike_yielded == tick then return true, false, 0 end

	-- Compute caps
	local work_current, work_cap =
		task._cmt_work_current or 0, max(task._cmt_work_cap or 1, 1)
	if work_current >= work_cap then return true, false, 0 end

	-- Exec
	task._cmt_yielded = nil
	running_task = task
	running_work_done = frame_work_done
	running_work_cap = frame_work_cap
	task._cmt_spike_yielded = nil
	local work_done = max(task:main() or 0, 1)
	running_task = nil

	-- Determine stats
	update_era_counter(task._cmt_work_per_iter, work_done)
	work_current = work_current + work_done
	task._cmt_work_current = work_current

	-- Determine whether to yield
	if task._cmt_yielded or (work_current >= work_cap) then
		return true, true, work_done
	end
	return false, true, work_done
end

---@param runq Core.CMT.Task[]
---@param work_done number
local function runq_clean(runq, work_done)
	filter_in_place(runq, function(task)
		if task._cmt_dead then
			local data = get_cmt_storage()
			data.tasks[task._cmt_id] = nil
			return false
		else
			return true
		end
	end)
end

---@param runq Core.CMT.Task[]
---@param pointer uint
---@param task Core.CMT.Task
---@return uint pointer
local function runq_move_to_end(runq, pointer, task)
	for index = 1, #runq do
		if runq[index] == task then
			tremove(runq, index)
			if index < pointer then pointer = (pointer - 1) end
			if pointer > #runq then pointer = 1 end
			---@cast pointer uint
			if pointer == 1 then
				tinsert(runq, task)
			else
				tinsert(runq, pointer, task)
				pointer = pointer + 1
			end
			return pointer
		end
	end
	return pointer
end

---@param runq Core.CMT.Task[]
---@param pointer uint The index of the task to start from.
---@param work_done number The amount of work done so far in this frame.
---@param work_cap number The maximum amount of work to do.
---@param tick uint64 The current tick.
---@param total_cycles uint The number of additional cycles to allow after the runqueue has been exhausted.
---@return uint next_pointer The index of the next task to run.
---@return number work_done The amount of work done in all executed steps.
local function runq_steps(
	runq,
	pointer,
	work_done,
	work_cap,
	tick,
	total_cycles
)
	if #runq == 0 then return 1, work_done end
	local cycles = 1
	local task = runq[pointer]
	while work_done < work_cap do
		-- Normalize task
		if task and not task._cmt_work_current then
			strace.warn("Task had no work_current", task._cmt_name or task._cmt_id)
			task._cmt_work_current = 0
		end

		-- Step task
		local advance, ran, work = runq_step_task(task, tick, work_done, work_cap)
		work_done = work_done + work
		if advance then
			-- Cleanup task that ran
			if task then task._cmt_work_current = 0 end

			pointer = (pointer + 1) --[[@as uint]]
			task = runq[pointer]
		end
		if not task then
			-- Queue finished
			runq_clean(runq, work_done)
			if cycles >= total_cycles then
				return pointer, work_done
			else
				cycles = cycles + 1
				pointer = 1
				task = runq[pointer]
			end
		end
	end
	return pointer, work_done
end

---@param task Core.CMT.Task
---@param tick uint
local function wake_task(task, tick)
	if task._cmt_dead then return end
	task._cmt_awake = true
	task._cmt_tick_slept = nil
end

---@param tick_data NthTickEventData
local function scheduler_tick(tick_data)
	local data = get_cmt_storage()
	local tick = tick_data.tick

	-- Add any woken tasks to this frame's runqueue
	local wake_now = data.wake_at[tick]
	if wake_now then
		for task in pairs(wake_now) do
			wake_task(task, tick)
		end
		data.wake_at[tick] = nil
	end

	local work_cap = data.max_work_per_frame

	-- Run realtime tasks with no cap on work per frame
	local _, work_done =
		runq_steps(data.rq_realtime, 1, 0, REALTIME_WORK_CAP, tick, 1)

	-- A spike owner runs after realtime tasks and receives the only bypass.
	local spike_owner_id = data.spike_owner_id
	local spike_owner = spike_owner_id and data.tasks[spike_owner_id]
	if spike_owner and not spike_owner._cmt_dead and spike_owner._cmt_awake then
		data.spike_owner_id = nil
		spike_owner._cmt_work_current = 0
		running_as_spike_owner = true
		bypass_spike_yield = true
		local _, ran, work = runq_step_task(spike_owner, tick, work_done, work_cap)
		running_as_spike_owner = false
		bypass_spike_yield = false
		if ran then
			work_done = work_done + work
			spike_owner._cmt_work_current = 0
			spike_owner._cmt_spike_yielded = tick
			data.rq_normal_pointer =
				runq_move_to_end(data.rq_normal, data.rq_normal_pointer, spike_owner)
		end
	elseif spike_owner_id and not spike_owner then
		data.spike_owner_id = nil
	elseif
		spike_owner and (spike_owner._cmt_dead or not spike_owner._cmt_awake)
	then
		data.spike_owner_id = nil
	end

	-- Run normal tasks with the remaining work cap
	if work_done < work_cap then
		local next_pointer = runq_steps(
			data.rq_normal,
			data.rq_normal_pointer,
			work_done,
			work_cap,
			tick,
			2
		)
		data.rq_normal_pointer = next_pointer
	end
end

if not _G.__RECOVERY_MODE__ then
	events.bind(events.nth_tick(1), scheduler_tick)
end

events.bind("on_shutdown", function()
	local data = get_cmt_storage()
	data.tasks = {}
	data.wake_at = {}
	data.rq_realtime = {}
	data.rq_normal = {}
	data.rq_normal_pointer = 1
	data.spike_owner_id = nil
end)

--------------------------------------------------------------------------------
-- Task Control
--------------------------------------------------------------------------------

---@param task_id Core.CMT.TaskID?
---@return Core.CMT.Task? The task with the given ID, or nil if no such task exists.
function lib.get(task_id)
	if not task_id then return nil end
	local task = get_cmt_storage().tasks[task_id]
	if (not task) or task._cmt_dead then return nil end
	return task
end

---@return table<Core.CMT.TaskID, Core.CMT.Task> tasks The set of all tasks.
function lib.get_tasks() return get_cmt_storage().tasks end

---Yield the current task, allowing other tasks to run this frame instead. Note that calling this on a task that is not currently running will have no effect.
---@param task Core.CMT.Task The task to yield.
function lib.yield(task) task._cmt_yielded = true end

---Yield before performing a costly operation if its estimated workload would
---reach a scheduler cap. Returns `true` when the caller should return from its
---main loop without performing the operation. The first normal task to spike
---yield runs after realtime tasks next frame and bypasses one spike yield to
---prevent deadlock. An owner cannot reclaim ownership until it runs normally.
---Realtime tasks cannot spike yield.
---@param task Core.CMT.Task The currently running task.
---@param upcoming_work number? Estimated workload of the pending operation.
---@return boolean yielded Whether the task yielded due to the predicted spike.
function lib.spike_yield(task, upcoming_work)
	if task ~= running_task then return false end
	if (not upcoming_work) or upcoming_work <= 0 then return false end
	if task._cmt_realtime then return false end
	if bypass_spike_yield then
		bypass_spike_yield = false
		return false
	end

	local work_cap = max(task._cmt_work_cap or 1, 1)
	if
		(task._cmt_work_current or 0) + upcoming_work >= work_cap
		or running_work_done + upcoming_work >= running_work_cap
	then
		task._cmt_spike_yielded = game.tick
		task._cmt_yielded = true
		local data = get_cmt_storage()
		if not running_as_spike_owner and not data.spike_owner_id then
			data.spike_owner_id = task._cmt_id
		end
		return true
	end
	return false
end

---Sleep the given task, optionally for a given number of ticks. If no duration is given, the task will sleep indefinitely until woken by another task.
---@param task Core.CMT.Task The task to sleep.
---@param duration? uint The number of ticks to sleep for. If nil, the task will sleep indefinitely.
function lib.sleep(task, duration)
	local data = get_cmt_storage()
	local tick = game.tick
	task._cmt_awake = false
	task._cmt_tick_slept = tick
	if duration and duration > 0 then
		local wake_tick = tick + duration
		task._cmt_tick_wake = wake_tick
		data.wake_at[wake_tick] = data.wake_at[wake_tick] or {}
		data.wake_at[wake_tick][task] = true
	end
end

--- Wake the given task, allowing it to run again. If the task is already awake, this has no effect.
---@param task Core.CMT.Task The task to wake.
function lib.wake(task)
	local tick = game.tick
	wake_task(task, tick)
end

---Kill the given task, preventing it from running again. If it is currently executing its mainloop, it will still finish that iteration.
---@param task Core.CMT.Task The task to kill.
function lib.kill(task) task._cmt_dead = true end

---Add a task to the CMT runqueue. Note that tasks begin sleeping by default and must also be woken before they will run. If the task is already in the runqueue, this will throw an error.
---@param task Core.CMT.Task The task to add to the runqueue.
function lib.add(task)
	if task._cmt_id then error("Task already added to CMT runqueue") end
	task._cmt_id = counters.next("_cmt")
	local data = get_cmt_storage()
	data.tasks[task._cmt_id] = task
	if task._cmt_realtime then
		tinsert(data.rq_realtime, task)
	else
		tinsert(data.rq_normal, task)
	end
end

---@return number max_work The target maximum amount of work to be done per frame across all tasks.
function lib.get_max_work_per_frame()
	return get_cmt_storage().max_work_per_frame
end

---@param max_work number The target maximum amount of work to be done per frame across all tasks.
function lib.set_max_work_per_frame(max_work)
	get_cmt_storage().max_work_per_frame = max_work
end

function lib.force_kill_all_tasks()
	---@diagnostic disable-next-line: undefined-field
	local data = storage._cmt --[[@as Core.CMT.Storage?]]
	if data then
		data.tasks = {}
		data.wake_at = {}
		data.rq_realtime = {}
		data.rq_normal = {}
		data.rq_normal_pointer = 1
		data.spike_owner_id = nil
	end
end

return lib
