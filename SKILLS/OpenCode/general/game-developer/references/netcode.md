# Multiplayer Netcode

## Pick a model first

This is the biggest architectural commitment in a multiplayer game. Choose based on the genre's demands.

| Model | Latency feel | Bandwidth | Complexity | Best for |
|-------|--------------|-----------|------------|----------|
| Client-side prediction + server authority | Low | Medium | Medium | Action games, shooters, fighting |
| Rollback | Very low | Medium | High | Fighting games, sports, tight competitive |
| Lockstep | Low | Very low | High (sync) | RTS, MOBA, deterministic sims |
| Snapshot interpolation | Medium | High | Low | Casual, strategy, many players |
| State sync | Medium | High | Low | Card/board, turn-based |
| Server-authoritative, no prediction | High | Medium | Low | Slow-paced, low action |

Do not build rollback for a turn-based game. Do not build lockstep for a fast shooter.

## The server is authoritative

- The client never decides its own position, damage, inventory, or score.
- The client sends **intent** ("I pressed jump at time T"), not state ("I am at x=100").
- The server simulates, validates, and broadcasts the authoritative state.
- The client predicts local input and reconciles when the server disagrees.

## Client-side prediction

The problem: the round trip is 50-200 ms, so local actions must feel instant. But the server can disagree.

```pseudo
# Client
input = poll()
predictedState = applyInput(predictedState, input)
sendToServer(input, sequenceNumber)

# On server state receipt
if serverState.sequence < lastAckedInput: ignore (stale)
predictedState = reconcile(serverState, pendingInputsAfter(serverState.sequence))
```

**Reconciliation**: keep a history of inputs with their sequence numbers. When the server state arrives, re-apply the inputs that came after the server's last processed sequence.

```pseudo
# rollback-and-replay, the simplest correct approach
state = serverState
for input in inputs where input.seq > serverState.lastInputSeq:
    state = applyInput(state, input)
```

- If the prediction was correct, the replay produces the same state, and the player sees nothing.
- If not, the player snaps. Smooth small corrections by blending over a few frames; large corrections snap immediately (otherwise you rubber-band the camera).
- **Smoothing**: keep a `renderState` that lerps toward the predicted state at a limited rate. This hides small corrections without lying about large ones.

## Input delay

An alternative to prediction: delay the local view by a fixed amount (e.g. 100 ms) so that the server's response arrives on time. Simpler, and much cheaper than reconciliation, but it feels sluggish and is not viable for fast action.

## Entity interpolation

Remote entities are rendered in the past, between two received snapshots.

```pseudo
renderTime = serverTime - INTERPOLATION_DELAY   # typically 100ms
find snapshots A and B where A.time <= renderTime < B.time
renderPos = lerp(A.pos, B.pos, (renderTime - A.time) / (B.time - A.time))
```

- Keep a buffer of snapshots, sorted by time. Discard snapshots older than the interpolation window.
- Interpolate position, rotation, and animation time. Do not interpolate angle directly; interpolate the underlying vector or shortest-arc the angle.
- Extrapolate (predict forward) if no newer snapshot has arrived, but cap it at ~100 ms and freeze after that, so a network stall does not send entities flying.

## Lag compensation

The reverse problem: the server receives the client's shot after the client saw the target. The server must rewind the world to the client's view time.

```pseudo
onReceiveShot(clientTime, ray):
    world = rewindTo(serverTime - (now - clientTime))
    checkHit(world, ray)
    world = restoreCurrent()
```

- Cap the rewind window (e.g. 200 ms) to bound the cost and limit how far back a client can claim.
- Validate the claimed client time against the server's clock, and against the client's round-trip time, to prevent a client claiming an arbitrarily old timestamp.
- This is the classic "shot behind the cover" problem. There is no perfect answer; it is a trade-off between favouring the shooter and favouring the target.

## Tick rate

- Server tick: 30-60 Hz for action, 10-20 Hz for slow-paced games.
- Snapshot rate: 10-30 Hz. Send snapshots at a lower rate than the simulation tick.
- Send deltas, not full state, once the state is large.
- Prioritize: send the entities that are near the player or in combat first. The rest can be updated at a lower rate.
- Quantize positions and velocities to reduce bandwidth. Do not send raw floats.

## Client-side bandwidth reduction

- **Delta encoding**: send only what changed since the last acknowledged snapshot.
- **Acknowledge**: the client tells the server the last snapshot it received, so the server can drop older state.
- **Relevancy culling**: only send entities the client can see or interact with.
- **Area of interest**: assign entities to a grid cell and only send the relevant cells.
- **Quantization and packing**: pack booleans into bitfields, deltas into bytes.

## Authority and cheating

- Never trust the client for position, damage, currency, or inventory.
- Validate every action against the rules, on the server.
- Rate limit actions per client. A client sending 100 moves per second is either broken or attacking.
- Keep the server tick rate independent of any single client.
- For competitive games, consider server-side replay logs so disputes can be reviewed.

## Disconnection and reconnection

- Handle a dropped client gracefully: keep the state consistent, do not crash the server.
- On reconnect, send a full authoritative snapshot rather than deltas.
- Give the client a grace period to reconnect before removing the player.
- Communicate the disconnect to other players.

## Determinism requirements (for lockstep)

- Fixed timestep, identical across clients.
- Deterministic iteration order (sort by entity ID, never by pointer or hash order).
- A seeded PRNG with the same algorithm and state on every client. Never `Math.random()`.
- Floating point must be deterministic. Avoid `fast-math`, and avoid platform-specific math functions. Some engines provide a deterministic math library for this.
- No wall-clock time inside the simulation.
- The simulation must not read from the network, the filesystem, or the UI.

## Transport

- UDP for action games (low latency, no head-of-line blocking). Handle loss with redundancy: send the last N inputs, so one lost packet is recoverable.
- TCP for turn-based and card games where reliability matters more than latency.
- Use an encrypted channel (DTLS or a library-level encryption) with a connection handshake and a server address token to prevent source spoofing.
- Measure RTT, jitter, and packet loss separately. They need different responses.

## Common mistakes

- The client predicts but never reconciles, so the state drifts.
- The client sends state instead of intent.
- The server trusts the client's position.
- Interpolation delay is not tuned, so everything feels laggy or jittery.
- The rewind window is unbounded, so a client can claim an arbitrarily old timestamp.
- The snapshot rate equals the tick rate, which wastes bandwidth.
- No rate limiting on client actions.
- The game is tested only on a LAN, where the problems do not appear.
