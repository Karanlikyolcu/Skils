# Entity Component Systems

## Why

Object-oriented entity hierarchies scale badly: every entity update is a virtual call, entity data is scattered across the heap (cache misses), and adding a behavior means modifying a class, which ripples through the hierarchy.

ECS separates:

- **Entity**: an ID. Nothing else.
- **Component**: plain data. `Position`, `Velocity`, `Health`, `Sprite`, `PlayerControlled`.
- **System**: logic over a query of matching components. `MovementSystem`, `RenderSystem`.

Benefits: contiguous memory for component data, behavior added without touching existing code, and a data layout the CPU can prefetch.

## Data layout

**Structure of arrays (SoA)** - one array per component type, indexed by entity.

```text
positions: [vec3, vec3, vec3, ...]
velocities: [vec3, vec3, vec3, ...]
```

Iterating all velocities reads one contiguous block. Iterating an array of structs (`[pos, vel, health]`) touches three times the memory per entity, because each entity pulls in unrelated fields.

Use SoA for hot components (position, velocity, health) and array of structs for cold, complex ones (an entity with 30 rarely-read fields).

**Packing**: store components densely with an entity-to-index map, so there is no gap when an entity dies. In a simple implementation, leave the slot empty and mark it free; in a packed one, swap the last element into the hole and update the map.

**Alignment**: SIMD-friendly layouts want components in groups of 4 floats. Many engines let you declare a component as `float4` so it fits a vector instruction.

## Queries and iteration

A query is a set of entities with all the requested components.

```pseudo
for entity in query(Position, Velocity):
    pos = position[entity]
    vel = velocity[entity]
    position[entity] = pos + vel * dt
```

- Queries are built once and cached. Rebuilding the entity list every frame is expensive.
- Matching is usually tracked incrementally: a component is added or removed, and the query membership is updated then.
- **Access conflict**: a system that writes `Position` cannot run at the same time as one that reads it, if the order is not defined. Declare read/write access per component and let the scheduler order the systems. This is how parallelism is enabled later.
- Prefer explicit ordering when the order carries meaning (input before movement before collision).

## Tags

A tag is a component with no data, used for classification.

```text
PlayerControlled, Enemy, Projectile, Wall, Dead
```

Tags make queries expressive: `query(Position, Velocity, Projectile)` is exactly the bullets.

## Systems

- A system holds logic, not state. State lives in components.
- A system declares the components it reads and writes.
- Systems should be small. One system, one concern. `MovementSystem` does not also handle collisions.
- System update order is explicit and documented. Never rely on registration order by accident.

## Transform hierarchy

Hierarchies are the one place a naive ECS gets awkward.

```text
LocalTransform  (relative to parent)
WorldTransform  (computed)
```

- A `TransformSystem` computes `WorldTransform` from `LocalTransform` and the parent's `WorldTransform`.
- Only recompute when dirty: mark a transform dirty when it or an ancestor changes. A per-frame full traversal of the whole hierarchy is wasteful.
- Use a topological order (parents before children) so one pass suffices.
- For deep hierarchies (skeletons, UI trees), consider skipping the hierarchy and computing world matrices directly for the nodes that need them.

## Entities as IDs

- Use a dense integer ID with a generation counter so a stale ID is detected rather than silently referring to a new entity.
- Keep entity IDs in a stable array, with a free list for reuse.
- Do not store entity references inside components. Store IDs. A direct pointer creates lifetime problems.

## Adding behavior without modifying the system

The key benefit: new behavior is a new system plus possibly a new component, with no change to existing code.

```text
Before: entity has Position, Velocity, Health
Add:    new component MagnetField, new system MagnetSystem
After:  entity has Position, Velocity, Health, MagnetField
```

Existing systems are untouched. This is the "open for extension, closed for modification" idea, applied to data.

## Data-oriented design in practice

The ECS idea extends beyond the engine:

- **Hot data in arrays, cold data in objects.** A million enemies: store position, velocity, health, and state in flat arrays; store the "special" data (inventory, dialogue tree) in a sparse map keyed by entity, only for entities that have it.
- **Process in batches.** Instead of updating enemies one at a time, update all of them in a tight loop over contiguous arrays. This is where the SIMD speedup comes from.
- **Branching hurts.** A `switch` on entity type inside a hot loop breaks vectorization. Split the data by type so each loop handles one type.

```pseudo
# Branchy (bad)
for e in enemies:
    match e.type:
        case FLYER:  update_flyer(e)
        case WALKER: update_walker(e)

# Data-oriented (good)
for e in flyers:  update_flyer_batch(flyers)    # tight loop, no branch
for e in walkers: update_walker_batch(walkers)
```

## Hybrid approach

Most shipped games are hybrid:

- ECS for the simulation layer (entities, physics, AI, spawning) where there are many similar objects.
- Regular objects for unique, complex things: the player character, bosses, UI, scripted sequences, level state.
- A bridge so each can reference the other by ID.

Do not force everything into the ECS. The cost of a pure ECS in complexity is real, and a game with 200 entities does not need one.

## When an ECS is worth it

| Situation | ECS worth it? |
|-----------|----------------|
| Hundreds of entities | No, plain objects are fine |
| Tens of thousands of similar entities | Yes |
| Frequent spawning and despawning | Yes |
| Many interacting behaviors, added over time | Yes |
| A small puzzle game | No |
| Prototype | No, prototype with plain objects |

## Common mistakes

- Storing behavior in components. Components are data.
- Adding a component to an entity every frame. Membership updates are not free.
- Iterating all entities and checking components manually instead of using a query.
- Forgetting to mark a transform dirty after changing a parent's position.
- Unbounded systems that touch every entity when only a few are relevant.
- Rebuilding query lists every frame instead of caching them.
- Mixing render data into the simulation layer, so a renderer change forces a simulation rewrite.
