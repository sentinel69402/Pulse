local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Pulse = require(ReplicatedStorage.Shared.Pulse)

RunService.Heartbeat:Connect(function(dt)
	Pulse.step(dt)
end)

local function benchmark(label: string, duration: number)
	print(`\n--- Benchmark: {label} ({duration}s) ---`)
	
	-- task.wait
	task.spawn(function()
		local start = os.clock()
		task.wait(duration)
		local elapsed = os.clock() - start
		print(string.format("[task.wait] Target: %.4fs | Actual: %.4fs | Error: %+.6fs", duration, elapsed, elapsed - duration))
	end)

	-- Pulse
	local startClock = os.clock()
	Pulse.after(duration, function()
		local elapsed = os.clock() - startClock
		print(string.format("[Pulse    ] Target: %.4fs | Actual: %.4fs | Error: %+.6fs", duration, elapsed, elapsed - duration))
	end)
end

task.delay(2, function()
	benchmark("Short", 0.1)
	benchmark("Medium", 0.5)
	benchmark("Long", 1.0)
	benchmark("Very Long", 2.0)
end)

