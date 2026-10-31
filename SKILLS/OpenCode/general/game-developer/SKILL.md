---
name: Game Developer
description: Use for game development - game loop and frame timing, fixed timestep and interpolation, entity component systems and data-oriented design, physics and broadphase collision, AI and behavior state machines, rendering and asset pipelines, input handling, animation, audio, object pooling, multiplayer netcode and rollback, and frame budget optimization.
metadata:
  opencode/autoinvoke: true
license: MIT
---

# Game Developer

A game is a loop that must hit a deadline 60 times per second, forever, while looking and feeling good. Every decision in game code is really a decision about time.

## 1. The frame budget comes first

60 FPS = 16.67 ms per frame. 30 FPS = 33.3 ms. Budget the whole frame, not per system in isolation.

| Stage | Typical budget @60 |
| ----- | ------------------ |
| Input sampling | 0.5 ms |
| Fixed-step simulation | 3-4 ms |
| Rendering preparation | 2-3 ms |
| Draw submission | 3-4 ms |
| GPU wait | 3-4 ms |
| Slack for spikes | 2 ms |

Budgets are a design constraint, not an afterthought. A feature that cannot fit the budget does not ship in that form; it needs a cheaper implementation, a lower frequency, or a cut.

Measure the frame: render a per-system timing overlay early, and profile with the platform profiler. Never optimize from intuition.

## 2. The loop and time

Two loop styles, and the difference matters:

**Variable timestep** - `dt` is the real elapsed time. Simple, but physics becomes non-deterministic across machines and a 200 ms hitch tunnels the player through a wall.

**Fixed timestep** - simulate in constant steps (e.g. 1/60 s) with an accumulator, and render interpolated between the last two simulation states.

```pseudo
accumulator += min(realDelta, MAX_FRAME_DELTA)   // clamp: never simulate a huge catch-up
while accumulator >= FIXED_DT:
    simulate(FIXED_DT)
    accumulator -= FIXED_DT
    render(alpha = accumulator / FIXED_DT)
```

Rules that follow from this:

- Clamp the incoming delta. After a stall, simulate a bounded number of steps, or the game freezes while catching up.
- Render interpolates between `previousState` and `currentState` using `alpha`. Visual smoothness without extra simulation cost.
- Physics and gameplay use fixed steps. Cosmetic effects (particles, UI easing, camera smoothing) can use real time.
- Never let `dt` be zero (division by zero) or unbounded.
- Determinism matters for netcode and replays: fixed steps, deterministic iteration order, no wall-clock time inside simulation, no random calls outside a seeded RNG.

## 3. Architecture: entity, component, system

Classic object-oriented hierarchies become a performance wall: deep per-object update calls, virtual dispatch in the hot path, scattered data that the CPU cache cannot hold.

An ECS separates identity, data, and behavior:

- **Entity**: an ID. No data of its own.
- **Component**: plain data. `Position`, `Velocity`, `Health`, `Renderable`.
- **System**: logic over a query of matching components. `MovementSystem`, `HealthSystem`.

Why it wins: systems iterate contiguous arrays of component data, which is cache-friendly and SIMD-friendly. Behavior can be added without touching existing code.

Practical rules:

- Components hold data only. No behavior methods inside a component beyond trivial accessors.
- Systems are stateless or hold only global state. State lives in components.
- Queries by component tag: iterate all entities with Position+Velocity, not "all entities and check".
- Use structure-of-arrays storage for hot components.
- Keep the transform hierarchy explicit: `LocalTransform` plus `WorldTransform`, updated by a dedicated transform system with dirty flags, not by recomputing everything every frame.
- Not every game needs a full ECS. A small game with a few hundred entities is fine with plain objects. A large game with tens of thousands of entities is not.

## 4. Physics and collision

**Integration**: semi-implicit Euler for most cases (`v += a*dt; p += v*dt`), fixed step. Verlet or RK4 only when the extra stability is genuinely needed.

**Broadphase**: cull the pairs before testing them. A spatial hash grid, a BVH, or a swept-and-pruned list. Quadratic all-pairs is only acceptable for small counts.

**Narrowphase** by shape:

| Pair | Method | Notes |
| ---- | ------ | ----- |
| AABB / AABB | Overlap test | Fastest, use for broadphase |
| Circle / circle | Distance vs radius sum | Cheap and stable |
| AABB / circle | Closest point test | Good for tiles and bullets |
| AABB / AABB | Overlap test | Standard for 2D platformers |
| Sphere / sphere | Distance test | 3D equivalent of circle |
| Sphere / AABB | Closest point | Common in 3D |
| Convex / convex | GJK + EPA | Full SAT is expensive |
| Concave | Decompose into convex | Or use a physics engine |

Practical points:

- Trigger volumes and solid bodies are different queries. A player standing on a sensor should not be blocked by it.
- Resolve with position correction plus velocity projection. Handle the overlap case without adding energy.
- Use continuous collision detection for fast projectiles (raycast against the sweep path) to prevent tunneling.
- Layer masks prevent unnecessary pair tests. Put objects on layers that never need to collide.
- Sleep bodies that have not moved, so they cost nothing.
- Deterministic physics: same inputs, same outputs, across machines, if you need lockstep or rollback netcode.

## 5. Gameplay logic and AI

- Finite state machines for behavior (idle, chase, attack, flee, dead). Explicit states with explicit transitions beat nested `if` chains.
- Behavior trees for composing many behaviors. Keep them data-driven so designers can tune without a recompile.
- Utility AI for weighted scoring. Use it when the agent must weigh several competing options rather than follow one path.
- Pathfinding: A* on a grid or navmesh, with path smoothing, and a budget. Cap the number of agents that re-path per frame; stagger them.
- Steering behaviors (seek, flee, arrive, separate) for fluid motion without full pathfinding.

**Game feel** - the difference between a mechanic that works and one that feels good:

- **Input buffering**: remember an input for ~150 ms so a jump pressed slightly early still fires on landing.
- **Coyote time**: allow jumping for ~100 ms after leaving a ledge.
- **Jump forgiveness**: widen the landing window, or auto-correct small landing offsets.
- **Hit-stop / freeze frames**: 50-100 ms freeze on impact, plus screen shake, punch-out zoom, and impact particles.
- **Anticipation and follow-through**: wind up before the action, overshoot slightly, settle back.
- **Audio-visual sync**: pair the sound with the animation and the particle, at the same frame.
- **Tuning constants** in one place, named and tunable, not scattered magic numbers.

## 6. Rendering

- Understand the cost drivers on the target platform: draw calls, state changes, shader complexity, overdraw, vertex count, bandwidth.
- **Batch** aggressively. Group by material or texture atlas to minimize draw calls.
- **Atlas** sprites and textures so many objects share one material.
- **Cull** what is off-screen, and use LODs for distant objects.
- **Pool** everything that is created and destroyed frequently: bullets, particles, damage numbers. Allocating in the hot loop causes GC spikes and frame hitches.
- Keep the GPU busy but the CPU cheap: the CPU submits, the GPU waits. Balance them.
- Avoid per-object material or shader switches in the hot path; they cause pipeline state changes.
- Compute the visual result at a lower frequency than the simulation when it is acceptable: UI layout, some particles, camera smoothing.

## 7. Input

- Sample input once per frame into a stable state. Never poll raw device state deep inside gameplay code.
- Support input buffering and rebinding. Hard-coded keys make the game feel broken on other layouts.
- Handle device loss, focus loss, and controller disconnect gracefully. Pause and release held buttons on focus loss.
- Support simultaneous inputs on keyboard, mouse, gamepad, and touch. Normalize them into the same action set.
- Accessibility: remappable keys, adjustable sensitivity, hold vs toggle for sprint, colorblind-safe UI, subtitle options, adjustable timing.

## 8. Audio and haptics

- Use a small number of pooled voices; streaming long music is cheap, but many simultaneous effects need voice limiting and priority.
- Trigger sounds from gameplay events, not from animation frames, so audio stays in sync with logic.
- Apply ducking (lower music volume under speech or important cues) and fades to avoid clicks on stop.
- Respect platform audio focus: pause on phone call, handle headset unplug.

## 9. Netcode

Pick a model deliberately; this is the single biggest architectural commitment in a multiplayer game.

| Model | Use when | Cost |
| ----- | -------- | ---- |
| Client-side prediction + server authority | Action games, shooters | Moderate |
| Lockstep | Deterministic sim, RTS / MOBA | High sync cost, tiny bandwidth |
| Snapshot interpolation | Slow-paced, many players | Simple, some latency |
| State sync (server sends full state) | Casual, board/card | Simple, bandwidth heavy |
| Rollback | Competitive fighting / sports | Complex, needs prediction |

Rules for any model:

- The server is authoritative. The client predicts only for local input.
- Never trust the client with position, damage, or inventory state.
- Interpolate remote entities by a small delay (100 ms typical) to hide jitter.
- Send deltas, not full state, once the state is large.
- Quantize and prioritize: not every field needs to be sent every tick.
- Handle latency, jitter, and packet loss explicitly. Measure RTT and treat outliers as a different mode.
- Design for disconnect and reconnection from the start.

## 10. Ship it

- Profile before optimizing. Use the platform profiler and a frame-time overlay.
- Fix the worst offender first. Usually the answer is not micro-optimization but fewer objects, fewer draw calls, or a lower update frequency.
- Target the lowest common denominator: the weakest device in the supported set defines the budget.
- Test on real hardware, not only the editor. Editor performance does not predict device performance.
- Add a soak test: run for an hour and watch for memory growth, leaks, and frame-time drift.

## Supporting files

- `references/game-loop.md` - fixed timestep, interpolation, time scaling, pause, frame pacing.
- `references/ecs.md` - entity component system patterns, queries, storage layout, dirty flags.
- `references/collision.md` - broadphase and narrowphase techniques, resolution, tunnelling, layers.
- `references/game-feel.md` - input buffering, coyote time, hit-stop, camera, juice.
- `references/optimization.md` - profiling, draw call reduction, pooling, GC control, memory budgets.
- `references/netcode.md` - prediction, rollback, interpolation, snapshots, lag compensation.
