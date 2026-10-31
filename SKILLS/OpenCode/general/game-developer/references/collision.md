# Collision Detection and Resolution

## The two phases

**Broadphase**: cheaply find the pairs that might overlap. This removes the O(n²) problem.

**Narrowphase**: exactly test each candidate pair.

Never skip the broadphase. With 1,000 objects, all-pairs is 500,000 tests per frame, most of them wasted.

## Broadphase techniques

| Technique | Best for | Notes |
|-----------|----------|-------|
| AABB tree (BVH) | Static or rarely-moving geometry | Fast, needs rebuilds on change |
| Spatial hash grid | Many similar-sized objects in a bounded area | Simple, cache-friendly, poor for varied sizes |
| Sweep and prune | Many objects, sorted on one axis | Very fast when the sort order barely changes |
| Octree / quadtree | Large, hierarchical 2D worlds | Good for terrain and scattered objects |
| BVH with refitting | Deforming geometry (skinned meshes) | Refit bounds per frame |
| Layer masks | Always | Skip pairs that can never interact |

**Spatial hash grid** in detail - the usual choice in 2D games:

```pseudo
cellSize = maxObjectSize
cells = hashmap<cellKey, list<entity>>

for e in entities:
    key = cellOf(e.position)
    cells[key].add(e)

for e in entities:
    for neighbor in 3x3 cells around e:
        for other in cells[neighbor]:
            if e.id < other.id:        # process each pair once
                narrowphase(e, other)
```

- Insert into every cell the object's bounds overlap, not just the one containing its center, or fast objects are missed.
- Cell size near the average object size is the sweet spot.
- Sort by ID to avoid testing each pair twice.

## Narrowphase by shape

**AABB / AABB** - the workhorse. Separating axis test on both axes.

```pseudo
overlap = a.min.x <= b.max.x and a.max.x >= b.min.x
     and a.min.y <= b.max.y and a.max.y >= b.min.y
```

**Circle / circle** - distance between centers vs the sum of radii.

**AABB / circle** - closest point on the AABB to the circle center, then distance vs radius. This is the standard tile-vs-bullet test.

**Sphere / sphere** - same as circle, in 3D.

**Sphere / AABB** - closest point on the box to the sphere center.

**OBB** - SAT with up to 15 axes. Expensive; use a sphere or AABB approximation as a broadphase first.

**Convex / convex** - GJK for the intersection test, EPA for the penetration depth. Correct and general, but slower than a specialized test.

**Concave** - decompose into convex pieces (triangle soup) or use a physics engine. Never do concave-vs-convex directly.

**Heightfield / terrain** - sample the height under the object, compare with the object's height. Cheap and exact enough for most terrain.

## Resolution

After detecting an overlap, separate the bodies and cancel the velocity into the contact normal.

```pseudo
# 1. Find the minimum translation vector (MTV)
#    the smallest push that separates the shapes
n = minTranslationVector(a, b)
penetration = depth

# 2. Push apart, weighted by inverse mass
a.position += n * (penetration * invMassA / (invMassA + invMassB))
b.position -= n * (penetration * invMassB / (invMassA + invMassB))

# 3. Cancel the normal component of the relative velocity
relVel = b.velocity - a.velocity
sepVel = dot(relVel, n)
if sepVel < 0:
    impulse = -sepVel / (invMassA + invMassB)
    a.velocity -= n * (impulse * invMassA)
    b.velocity += n * (impulse * invMassB)
```

- Use inverse mass so that a heavy body barely moves and a light one moves a lot. A static body has inverse mass 0.
- Push apart before cancelling velocity, otherwise the objects stay overlapped and the next frame detects it again.
- Use a small slop (e.g. 0.01 units) and allow a small amount of overlap, to avoid jitter from floating-point error.
- Restitution (bounce) below 1 loses energy. Use 0 for most things and a small value for balls.

**Ground detection**: after resolution, check whether the contact normal points up (in 2D, `n.y > threshold`). Do not infer it from the absence of vertical velocity, which fails on slopes.

**Surface material**: friction and restitution per surface. A restitution above 1 adds energy and causes jitter.

## Continuous collision detection

Discrete tests miss fast objects: a bullet moving 50 units per step can pass straight through a 2-unit wall.

- **Swept test**: cast the shape's motion segment (a ray for a point, a shape-cast for a full shape) against the candidates.
- **Substepping**: divide the movement into steps no larger than the smallest object. Simple and effective, but it multiplies the collision cost.
- Use CCD only for the few objects that need it (bullets, missiles, fast vehicles). Applying it to everything is wasteful.

## Layers and filtering

Assign each object to layers and use a matrix of which pairs interact.

```text
Player      collides with: Wall, Enemy, Pickup
Enemy       collides with: Player, Wall, Enemy
Projectile  collides with: Wall, Enemy, Player
```

- This eliminates most unnecessary pair tests at the broadphase level.
- Triggers (sensors) are a separate query from solid bodies. A player standing on a pickup trigger should not be blocked by it.
- Team or faction filters are also common: friendly fire off.

## Moving platforms

- Detect a platform the entity is standing on, and apply the platform's delta (including rotation) to the entity.
- Carry the entity's velocity so it does not slide off.
- The order matters: move the platform, resolve the platform's own collisions, then move and resolve the riders.
- Use a kinematic body for platforms, and treat them as infinite mass.

## Stability

- **Speculative contacts**: instead of resolving after an overlap, prevent the overlap from happening by limiting velocity based on the time of impact. This removes the "caught in geometry" problem entirely.
- **Depenetration**: if an entity starts overlapped (spawned inside geometry), push it out gradually over several frames instead of teleporting it, which causes visible popping.
- **Deterministic ordering**: resolve collisions in a stable order (by entity ID), or two bodies can trade positions and jitter.
- **Small steps**: the smaller the step, the less penetration there is to resolve, and the more stable the result.

## Performance

- Keep the broadphase tight. It should reduce N² pairs to roughly N × k, where k is the average number of neighbours.
- Cache broadphase results for static geometry.
- Sleep bodies that have not moved for a while. They are skipped entirely.
- Use simpler shapes for broadphase and precise shapes only for narrowphase.
- Test with the profiler. Collision is often not the bottleneck; the broadphase allocation churn is.

## Common mistakes

- Checking collisions after moving, and not resolving before the next frame's movement. Order: integrate, detect, resolve.
- Not filtering pairs, so every projectile tests every particle.
- Using radius-only collisions for a player who must fit through a doorway.
- Forgetting that a moving entity's swept volume is larger than its static one.
- Mixing collision layers with gameplay logic. Keep "can these touch" separate from "what happens when they do".
- Not handling the case where two entities start exactly on a boundary, which produces a flip-flop between two states.
