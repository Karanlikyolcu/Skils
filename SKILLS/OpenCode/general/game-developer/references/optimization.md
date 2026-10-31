# Optimization and Profiling

## Measure first

Never optimize on intuition. The bottleneck is almost never where you expect it.

- **Platform profiler**: Instruments, Xcode Instruments, Android Studio Profiler, PIX, RenderDoc, Nsight.
- **GPU profiler**: captures a frame and shows where the time goes on the GPU.
- **In-engine timing overlay**: a per-system breakdown drawn on top of the game. Cheap to build, and the highest-value tool for finding a simulation bottleneck.
- **Counters**: draw calls, triangles, state changes, allocations per frame, entity count, physics pairs tested.

Record the target: 16.67 ms at 60 fps. Then measure a real frame on the weakest supported device, not in the editor.

## CPU optimization

**Allocation** - the most common hidden cost. Every allocation is CPU time, plus GC pressure later.

- Object pooling for anything created and destroyed frequently: bullets, particles, damage numbers, audio voices, network packets, temporary vectors.
- Preallocate scratch buffers and reuse them instead of creating temporaries in a loop.
- Avoid allocations in the render loop entirely.

**Data layout** - cache misses dominate tight loops.

- Structure of arrays for hot components.
- Keep per-entity data contiguous.
- Sort entities so that similar data is adjacent, and process in batches.

**Branching** - a branch misprediction costs ~10-20 cycles.

- Keep the hot path branch-free where possible.
- Split data by type so a `switch` becomes separate tight loops.
- Replace branches with arithmetic or lookup tables in the hottest code.

**Math** - transcendentals are expensive.

- Cache `sin`/`cos` for angles used repeatedly.
- Use squared distances instead of `sqrt` when only the comparison matters.
- Use fast approximations where the error is acceptable (e.g. a fast inverse square root).
- Precompute constants; do not recompute them per frame.

**Virtual dispatch** - a megamorphic call site (many types) prevents inlining.

- Specialize hot loops per concrete type.
- Use templates or generics so the compiler can specialize.

**Parallelism**

- Job systems for independent work: animation, AI, physics, rendering prep.
- Parallelize at a coarse granularity (thousands of entities per job), not per entity.
- Avoid locks in the hot path. Use double buffering or lock-free structures.
- Beware false sharing: two threads writing to the same cache line kills the gain.

## GPU and rendering optimization

**Draw calls** - usually the biggest cost on mobile.

- Batch by material or texture atlas.
- Use instancing for repeated geometry (rocks, trees, bullets).
- Combine static geometry into a single mesh.
- Use a texture atlas so many sprites share one material.
- Sort by material to minimize state changes.

**Shaders**

- Compile variants ahead of time, or precompile during a loading screen. A shader compiling mid-game is a visible hitch.
- Keep fragment shader cost low on mobile. Complex math in the fragment shader runs per pixel.
- Avoid overdraw: transparent layers drawn over each other are expensive. Sort transparent objects back to front, and minimize overlapping transparencies.
- Use LODs for distant objects, and reduce fragment work at distance.

**Culling**

- Frustum culling per object or per batch.
- Occlusion culling for interior scenes.
- Distance culling and small-object culling.
- Render distant objects with a simplified representation.

**Resolution**

- Render at a lower internal resolution and upscale. A common and effective mobile technique.
- Adjust the dynamic resolution scale based on the measured frame time.

**Memory bandwidth** - on mobile, often the real limit.

- Use compressed textures (ASTC, ETC2).
- Reduce texture size and avoid mipmap thrash.
- Minimize overdraw and blending.

## Memory

- Budget it. A typical mobile target: under 500 MB for a mid-range device.
- Watch for the texture atlas growing without bound.
- Free large buffers promptly; do not hold a peak buffer forever.
- Watch for leaks: a steady memory increase over a soak test is a leak.
- `malloc`/`new`/`delete` pairs in native code must be checked.
- Garbage-collected languages: allocation rate matters more than total heap. Aim for near-zero allocation per frame in the hot loop.

## Scheduling

- Spread work across frames. Not everything must happen every frame.
- Amortize: process 1/10 of the entities per frame for non-critical logic (AI far from the camera, path re-computation, animation updates for distant entities).
- Use time-slicing with a budget per frame rather than a fixed count.
- Prioritize by distance and visibility.

## Common bottlenecks and their fixes

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| GC pauses every few seconds | Allocation in the hot loop | Pool objects, reuse buffers |
| Spikes when entering a new area | Asset loading, shader compilation | Preload, precompile, stream |
| Slow with many objects | O(n²) logic, no broadphase | Spatial partitioning, layers |
| Low frame rate on low-end devices | Draw calls, overdraw, resolution | Batch, reduce resolution, LOD |
| Frame time varies wildly | Mixed workload | Profile per system, amortize |
| Physics slows with many bodies | Too many pairs | Broadphase, sleeping, simpler shapes |
| UI stutters | Layout recalculated every frame | Cache layouts, update at a lower rate |

## Profiling workflow

1. **Reproduce** on the target device, in a reproducible scene.
2. **Measure** the frame time breakdown, not just the average.
3. **Find the single biggest cost.** Fix that one thing.
4. **Re-measure.** Confirm the win and check that nothing else regressed.
5. **Stop** when the budget is met. Do not keep optimizing for diminishing returns.

Always compare against a baseline. Save a before/after number for every optimization, and keep the ones that did not help out of the codebase.

## Anti-patterns

- Optimizing before measuring.
- Micro-optimizing cold code.
- Adding a caching layer without an invalidation strategy.
- Assuming the editor's performance matches the device.
- Optimizing to a specific device instead of the weakest supported one.
- Adding complexity (a custom allocator, a custom scheduler) before the profile justifies it.
