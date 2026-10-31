# Game Feel and Juice

Game feel is the difference between a mechanic that works and one that feels good. It is a layer of small, deliberate choices applied to the simulation.

## Input responsiveness

**Input buffering** - remember the input for a short window so it fires when it becomes possible.

```pseudo
if jumpPressed:  jumpBuffer = 0.15
jumpBuffer -= dt
if onGround and jumpBuffer > 0:
    jump()
    jumpBuffer = 0
```

150 ms is a good default. This removes the "I pressed jump a fraction too early" complaint.

**Coyote time** - allow a jump for a short window after leaving the ground.

```pseudo
if onGround: coyoteTimer = 0.10
coyoteTimer -= dt
if jumpPressed and coyoteTimer > 0: jump()
```

100 ms is typical. This removes "I pressed jump just before landing and nothing happened".

**Landing forgiveness** - if the player lands slightly off a ledge, snap them onto it. Compute the distance to the nearest valid ground position within a small radius and correct it.

**Aim assist** - a subtle magnetism toward the nearest target within a small angle, scaled by distance. Make it optional and adjustable.

**Attack recovery and cancel windows** - allow the player to cancel an animation's recovery phase into the next action. Responsiveness lives here.

**Hold vs toggle** - let the player choose for sprint and similar. Support both.

## Impact feedback

The stack for a satisfying hit:

1. **Hit-stop / freeze frames** - 50-100 ms of near-zero time scale on impact. The single most effective technique. Implementation: scale `dt` in the simulation but keep rendering at full speed, and skip or shorten the audio during the freeze, or the audio will sound stuttered.
2. **Screen shake** - a decaying random offset applied to the camera. Amplitude and duration scale with impact. Keep it subtle; heavy shake is nauseating. Respect a reduced-motion setting.
3. **Camera punch** - a quick zoom-in and return, or a directional kick along the hit normal.
4. **Particles** - sparks, debris, blood, dust. Pooled.
5. **Flash** - the victim's sprite flashes white for 50-100 ms.
6. **Sound** - a layered impact sound: a low thud plus a high crack. Pitch varies slightly per hit so repeated hits do not sound identical.
7. **Haptics** - on controller and mobile, a rumble burst with the right intensity and duration.

**Knockback** - a short, sharp impulse. Long, gradual knockback feels mushy.

## Animation

- **Anticipation** - wind up before the action (2-4 frames at low speed). Sets up the strike.
- **Follow-through** - overshoot slightly past the target, then settle.
- **Squash and stretch** - squash on impact, stretch on launch. Scale along the motion axis.
- **Secondary motion** - hair, cloth, and accessories lag behind the body.
- **Overlap and offset** - for a walk cycle, one foot contacts before the other, and the hips shift.
- **Ease curves** - ease-in for wind-up, snap for the strike, ease-out for the settle. Linear looks robotic.

## Camera

- **Follow with a dead zone**: the camera does not move until the player leaves a small box. This removes jitter.
- **Smooth with damping**, not a hard follow. A critically damped spring feels right: `smoothTime` of about 0.15-0.3 s.
- **Look ahead**: offset the target in the direction of movement or input.
- **Dynamic framing**: pull back when moving fast or when enemies are off-screen.
- **Lead the action**: in a shooter, offset the camera toward where the player is aiming.
- **Screen shake** is applied as a camera offset, after all other camera logic, so it does not corrupt the follow behavior.

## Audio

- Trigger sounds from gameplay events, not from animation frames, so audio and logic stay in sync.
- Pitch variation: vary pitch ±5-10% per play so repeated sounds do not fatigue.
- Layer sounds: a base layer plus a variation layer plus an occasional special layer.
- Limit simultaneous voices with priority. Critical sounds (the player's own damage, the objective) get priority.
- Duck the music under important cues.
- Fade in and out to avoid clicks.

## Haptics

- Match intensity and duration to the event. A short sharp pulse for a hit, a sustained rumble for an engine.
- Respect the device's capabilities and the user's settings.

## UI and feedback

- **Hit markers** and **damage numbers**: brief, in the right place, animated. Damage numbers should not obscure the action.
- **Control feedback**: a button press must produce an immediate visual change. Response within one frame.
- **Sound and visual together**: pair them at the same frame.

## Difficulty and fairness

- **Telegraph attacks**: a wind-up animation and sound give the player time to react.
- **Give the player information**: flash the enemy before it strikes, show the attack direction.
- **Grace on failure**: brief invulnerability after taking damage, so a mistake is not a death spiral.
- **Input never lies**: the character must do what the player asked. No animation-driven input lag.

## Tuning constants

Keep them in one place, named, and adjustable:

```text
JUMP_HEIGHT = 3.2
JUMP_BUFFER_TIME = 0.15
COYOTE_TIME = 0.10
HIT_STOP_DURATION = 0.06
SHAKE_DECAY = 4.0
```

- These are game feel, not implementation. They are the most valuable numbers to tune and the easiest to bury accidentally.
- Expose them to a debug menu so they can be adjusted live.

## Checklist

- [ ] Input buffered and coyote time implemented
- [ ] Impact has hit-stop, shake, particles, sound, and flash
- [ ] Animations use easing and anticipation
- [ ] Camera has a dead zone, damping, and look-ahead
- [ ] Audio is triggered by events, varied in pitch, and voice-limited
- [ ] Feel constants are named and centralized
- [ ] Reduced-motion setting disables shake and heavy effects
