# Game Loop and Time

## Frame pacing

The loop runs at the display refresh rate (60, 120, 144 Hz). Everything else is scheduled inside it.

```pseudo
while running:
    frameStart = now()
    dt = now() - lastFrame
    lastFrame = now()

    input.sample()
    update(dt)
    render()

    sleep until next frame deadline
```

- **Frame pacing**: sleep until the next deadline rather than spinning. This keeps CPU usage low and motion smooth.
- **Delta clamping**: `dt = min(dt, MAX_DT)`. After a stall (loading, breakpoint, alt-tab), a huge delta would teleport everything.
- **Never use a variable timestep for physics.** Non-deterministic, and a single hitch can tunnel an object through a wall.

## Fixed timestep with interpolation

The standard solution. Simulate in constant steps, render the fractional remainder.

```pseudo
FIXED_DT = 1.0 / 60.0
MAX_FRAME_DELTA = 0.25
MAX_STEPS_PER_FRAME = 5

accumulator += min(realDelta, MAX_FRAME_DELTA)

steps = 0
while accumulator >= FIXED_DT and steps < MAX_STEPS_PER_FRAME:
    simulate(FIXED_DT)
    accumulator -= FIXED_DT
    steps += 1

if steps == MAX_STEPS_PER_FRAME:
    accumulator = 0          # give up on catching up; avoid a death spiral

alpha = accumulator / FIXED_DT
render(alpha)
```

**Why interpolation.** Rendering happens between two simulation states. Interpolate the visual position so movement stays smooth even though the simulation updates at a fixed rate.

```pseudo
renderPos = lerp(previousPos, currentPos, alpha)
```

- Keep `previous` and `current` state for the components that need smooth rendering (position, rotation, animation).
- Interpolation adds one frame of visual latency. That is imperceptible and far better than jitter.

**Choose the rate.** 60 Hz simulation matches most displays. 120 Hz simulation costs twice as much; only do it for fast action games where it is measurable. 30 Hz simulation is fine for slow strategy games and saves a lot of CPU.

**Determinism.** Fixed steps plus deterministic iteration order plus a seeded RNG plus no wall-clock reads inside the simulation. Required for lockstep netcode, replays, and rollback.

## Time scaling

- `timeScale` multiplies the delta passed to the simulation, not to the accumulator. Slow motion and fast forward affect gameplay but not the frame budget.
- `pause` freezes the simulation but keeps rendering and input alive.
- Separate three clocks: real time (UI, timers), scaled game time (gameplay), unscaled time (animations and effects that should keep running while paused).

## Update order

Order matters and must be consistent.

```pseudo
input
-> movement integration
-> collision detection and resolution
-> trigger/volume checks
-> state machine / AI
-> health, damage, death
-> cleanup (destroy dead entities)
-> animation update
-> camera update
-> render
```

Rules:

- Input is sampled once, before any update.
- Movement before collision, collision before anything that reads the resulting position.
- Cleanup last, so entities are not destroyed while other systems iterate over them.
- Never iterate a list while adding to or removing from it. Iterate over a snapshot, or mark for removal and clean up at the end.

## Death spirals and hitching

The classic failure: a slow frame makes the accumulator grow, which triggers more simulation steps, which makes the next frame slower.

Prevention:

- Clamp the incoming delta.
- Cap the number of steps per frame.
- Drop the accumulated remainder if the cap is hit (the game slows down briefly rather than stuttering forever).

Other causes of hitches and their fixes:

| Cause | Fix |
|-------|-----|
| Allocation in the hot loop | Object pooling |
| Loading assets synchronously | Preload, stream, and defer |
| Physics with too many pairs | Broadphase, layers, sleeping |
| Shader compilation at runtime | Precompile, or warm up during load |
| GC pause | Reduce allocation, reuse buffers |
| Too many draw calls | Batching, atlases, instancing |
| Large texture upload per frame | Atlas, or update less often |

## Frame budget

Measure per-system time with a timing overlay:

```pseudo
t0 = now(); input.sample();      record("input",   t0)
t0 = now(); simulate(FIXED_DT);  record("sim",     t0)
t0 = now(); prepareRender();     record("prepare", t0)
t0 = now(); draw();              record("draw",    t0)
```

Render the overlay as a histogram or a per-frame strip, not just a number. A single average hides spikes.

Budgets for a 60 Hz target:

| Stage | Budget |
|-------|--------|
| Input | 0.3 ms |
| Simulation | 3-5 ms |
| Animation + AI | 2 ms |
| Render prep | 2 ms |
| Draw submission | 2-3 ms |
| GPU | 4 ms |
| **Slack** | **2 ms** |

The slack is not optional. Without it, every minor variance becomes a dropped frame.

## Sleeping and pausing

- Pause on focus loss. Stop accumulating input, and release held buttons so the player does not walk into a wall when they return.
- Slow the update rate when nothing is happening: a menu can update at 10 Hz. An idle game can tick AI at 2 Hz.
- Sleep bodies and skip off-screen, distant, or inactive systems.

## Frame-rate independence

Anything that must behave the same at 30 and 144 fps uses `dt`:

```pseudo
position += velocity * dt
```

Anything that must be exact uses the fixed step. Choose per system and be consistent. A common bug is a timer that runs on real time while movement runs on fixed time, so they drift apart.

## Common pitfalls

- Using `Time.deltaTime` for physics on variable timesteps. Use a fixed step.
- Forgetting to clamp delta after a pause or a load.
- Interpolating only position and not rotation, so spinning objects jitter.
- Using the render frame time to drive a network tick. Network ticks have their own clock.
- Assuming 60 fps. Test at 30, 60, 144, and with a heavy load.
