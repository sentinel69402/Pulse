<img src="/assets/icon.png" width="64">

# Pulse

Pulse is a tiny, deterministic task scheduler for Roblox. It’s designed to be a simpler (and sometimes better) alternative to using `task.wait`, `task.delay`, or `task.spawn` for your game logic.

If you've ever dealt with "wait drift" or wanted to pause your entire game's logic with one function call, Pulse might be what you're looking for.

## Why Pulse?

Roblox's built-in `task` library is great, but it's tied directly to the engine's variable frame rate. Pulse uses a **fixed-step accumulator**. This means:

- **Consistency**: Your logic runs at a steady pace (defaulting to 60fps) regardless of lag spikes.
- **Time Scaling**: You can slow down or speed up global time easily.
- **Deteriminism**: Things happen in a predictable order.

---

## Quick Start

Pulse is a single module script. You'll need to "drive" it manually using a loop (usually `RunService.Heartbeat`).

### 1. Hooking it up

You only need to do this once, typically in a single server or client script.

```lua
local RunService = game:GetService("RunService")
local Pulse = require(path.to.Pulse)

-- Pulse needs to be "stepped" every frame to work!
RunService.Heartbeat:Connect(function(dt: number)
    Pulse.step(dt)
end)
```

### 2. Scheduling tasks

Once it's running, you can use it anywhere.

```lua
-- Run something once after 5 simulation seconds
Pulse.after(5, function()
    print("5 seconds later...")
end)

-- Run something every 1 second
local count = 0
local connectionId = Pulse.every(1, function()
    count += 1
    print("Tick:", count)
end)

-- If you need to stop a loop:
Pulse.cancel(connectionId)
```

---

## Neat Features

### Time Scaling

One of the coolest things about Pulse is that it tracks its own "simulation time" separately from the engine's time.

```lua
-- Make everything run at half speed (slow motion!)
Pulse.setTimeScale(0.5)

-- Or pause logic entirely without stopping the game
Pulse.pause()

-- Later...
Pulse.resume()
```

### Getting the current time

Instead of `tick()` or `os.clock()`, use `Pulse.now()`. It returns the number of simulation seconds that have passed since the game started (relative to the time scale!).

```lua
print("Simulation time is:", Pulse.now())
```

---

## API Reference

### `Pulse.step(dt: number)`

The engine calls this. You probably shouldn't call it yourself unless you're doing something fancy with custom loops.

### `Pulse.after(delay: number, callback: () -> ()): number`

Schedules a function to run once. Returns a task ID.

### `Pulse.every(interval: number, callback: () -> ()): number`

Schedules a function to run every `interval` seconds. Returns a task ID.

### `Pulse.cancel(taskId: number)`

Stops a scheduled task from running.

### `Pulse.setTimeScale(scale: number)`

Sets the speed of simulation. `1.0` is normal, `0.0` is effectively paused.

### `Pulse.setFixedDelta(dt: number)`

Sets the internal "tick rate". Default is `1/60`. You usually don't need to touch this unless you're building a very specific type of simulation.

---

## A few Caveats...

- **Registration Order**: Right now, tasks that should run at the same time are executed in the order they were registered. I might change this to a proper priority queue or min-heap later if it becomes a performance bottleneck, but for now, it's simple and fast.
- **No Error Handling**: If your scheduled function errors, it will currently stop the internal Pulse loop for that frame (if `STRICT_X` is true). Keep your callbacks clean!
- **Fixed Step**: Everything in Pulse happens on the fixed-step boundaries. If you need frame-perfect visual interpolation, you might still need to use `RenderStepped`.

I think that's about it! Feel free to open an issue or reach out if something feels broken.
