--!strict
-- Pulse 
-- Low-level deterministic timing and task scheduler.
-- Intentionally simple and explicit. 

local Pulse = {}

-- Types for internal clarity
type Task = {
	id: number,
	nextRun: number,
	interval: number?,
	fn: () -> (),
	cancelled: boolean,
}

--// Internal Configuration
-- If true, calls fn() directly. Faster, deterministic, but errors will stop the whole step.
-- If false, uses task.spawn(). Safer, but slightly less predictable ordering.
local STRICT_X = true 

--// Internal State
local tasks: {Task} = {}
local pendingTasks: {Task} = {}
local idToTask: {[number]: Task} = {}
local taskPool: {Task} = {}
local nextTaskId = 0

local accumulator = 0.0
local currentTime = 0.0
local fixedDelta = 1/60
local timeScale = 1.0
local isRunning = true

--// Internal Helpers

local function getTask(): Task
	local t = table.remove(taskPool)
	if t then
		return t
	end
	return {
		id = 0,
		nextRun = 0,
		interval = nil,
		fn = nil :: any, -- Will be set immediately
		cancelled = false,
	}
end

local function recycle(t: Task)
	-- Clear references to avoid memory leaks
	t.fn = nil :: any
	t.interval = nil
	t.cancelled = false
	table.insert(taskPool, t)
end

--// Configuration

--- Set the fixed physics/logic step. Default 1/60.
function Pulse.setFixedDelta(dt: number)
	assert(dt > 0, "fixedDelta must be positive")
	fixedDelta = dt
end

--- Set simulation time scale. 0 = paused, 1 = normal, 2 = 2x speed.
function Pulse.setTimeScale(scale: number)
	timeScale = scale
end

--// Getters

--- Get the current simulation time.
function Pulse.now(): number
	return currentTime
end

--// Task API

--- Schedule a function to run once after `delay` seconds.
--- Returns a taskId you can use to cancel.
function Pulse.after(delay: number, fn: () -> ()): number
	nextTaskId += 1
	local t = getTask()
	t.id = nextTaskId
	t.nextRun = currentTime + delay
	t.fn = fn
	
	idToTask[nextTaskId] = t
	table.insert(pendingTasks, t)
	return nextTaskId
end

--- Schedule a function to run every `interval` seconds.
--- First run occurs after `interval`.
function Pulse.every(interval: number, fn: () -> ()): number
	nextTaskId += 1
	local t = getTask()
	t.id = nextTaskId
	t.nextRun = currentTime + interval
	t.interval = interval
	t.fn = fn
	
	idToTask[nextTaskId] = t
	table.insert(pendingTasks, t)
	return nextTaskId
end

--- Cancel a scheduled task by ID.
function Pulse.cancel(taskId: number)
	local t = idToTask[taskId]
	if t then
		t.cancelled = true
		-- We don't remove from map/pool yet; the step loop handles it.
	end
end

--// Control API

function Pulse.pause()
	isRunning = false
end

function Pulse.resume()
	isRunning = true
end

--- Manual step function. Call this every frame (e.g. Heartbeat).
--- @param realDt The actual delta time from the engine.
function Pulse.step(realDt: number)
	if not isRunning then return end

	-- Prevent spiral of death if lag spike is huge
    -- Cap accumulator at something reasonable like 0.25s (15 frames)
	if realDt > 0.25 then realDt = 0.25 end

	accumulator += realDt * timeScale

	while accumulator >= fixedDelta do
		-- Core Simulation Step
		-- 1. Advance time
		-- 2. Run eligible tasks
		
		-- NOTE: We decrement BEFORE running tasks so that 'currentTime' is correct for the step?
		-- Actually, usually you process the step for time T, then advance to T+1?
		-- Let's stick to standard accumulation: consume accumulator -> simulate step.
		
		-- NOTE: We increment currentTime here to match the frame we are simulating.
		currentTime += fixedDelta
		accumulator -= fixedDelta

		-- 1. Flush pending tasks into the main loop
		-- We do this at the start of every fixed step so they are available immediately
		-- but didn't mess up the iteration of the *previous* step.
		if #pendingTasks > 0 then
			for _, pt in ipairs(pendingTasks) do
				table.insert(tasks, pt)
			end
			table.clear(pendingTasks)
		end

		-- Process tasks
		local writeIndex = 1
		local totalTasks = #tasks
		
		for readIndex = 1, totalTasks do
			local t = tasks[readIndex]
			local keep = true

			if t.cancelled then
				keep = false
			elseif t.nextRun <= currentTime then
				-- Execute
				if STRICT_X then
					t.fn()
				else
					task.spawn(t.fn)
				end

				-- Re-check cancelled because the fn() call might have cancelled itself
				if t.cancelled then
					keep = false
				elseif t.interval then
					t.nextRun += t.interval
				else
					keep = false
				end
			end

			if keep then
				tasks[writeIndex] = t
				writeIndex += 1
			else
				-- Cleanup
				idToTask[t.id] = nil
				recycle(t)
			end
		end

		-- Truncate the list
		for j = totalTasks, writeIndex, -1 do
			tasks[j] = nil
		end
	end
end

-- Known Issues
-- - The task priority is currently "registration order". A min-heap would make 
--   finding the next task O(1) but would break stable order and is more complex.
-- - No error-catching for user code.
-- - No specialized support for 'variable frequency' tasks (everything is fixed step).

return Pulse
