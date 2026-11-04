# Camera-based audio orientation — reuse guide

State on 2026-10-31. User accepted keeping this orientation after testing, without
separately confirming every camera. This guide describes behavior and portable
math for another mod.

## Behavior

Listener position follows the controlled player's head. Orientation changes
automatically:

| View | Audio orientation |
| --- | --- |
| General, including Dynamic Wide | Actual camera's horizontal direction |
| Player | Controlled player's horizontal body direction |

In a side-on broadcast, a goal on the right sounds right even when the player
turns. The far touchline can sound ahead and the near one behind. In Player
view, turning the athlete changes these bearings. Direction follows the actual
view, rather than fixing the opponent goal permanently on the right.

The mod positions its own WAVs. It does not capture or copy original stereo.
Listener position is at the player; original audio may use different mixing
rules, so this is not an exact reproduction. Visual camera behavior is unchanged.

## Inputs required from another game

Reacquire each update: active-play/pause/replay state; player and source positions
in consistent units/axes; actual camera type; actual camera yaw for general
views; and genuine player facing direction for Player view.

Our coordinates use metres, horizontal XY and height Z. Camera pitch/roll do not
tilt the ears toward the ground. Actual source height still affects positioning.

## Portable algorithm

For general views, with yaw in degrees:

```text
a = yaw * pi / 180
forward = (cos(a), sin(a), 0)
right = (-forward.y, forward.x, 0)
up = (0, 0, 1)
```

For Player view, substitute normalized horizontal body direction for `forward`.
Calculate `right` and `up` identically. For each source:

```text
delta = sourcePosition - playerHeadPosition
OpenAL.x = dot(delta, right)
OpenAL.y = dot(delta, up)
OpenAL.z = -dot(delta, forward)
```

OpenAL forward is negative Z. Sources are listener-relative
(`AL_SOURCE_RELATIVE = true`); do not apply the transform a second time through
another listener-position transform.

At yaw -90°, with player at origin, forward is negative Y and right is positive
X. A positive-X goal sounds right; the negative-Y touchline ahead, positive-Y
touchline behind. Validate finite values, unit lengths and orthogonality.
Unavailable/ambiguous orientation produces silence rather than guessed bearings
or stale game objects. Pause/replay/inactive play stops sources. Possession cues
are one-shot events, not restarted every frame.

## Owned-ball exception

When the genuine possession source reports `self`, place ball.wav at relative
`(0, 0, 0)` for centred stereo. A loose, teammate-owned or opponent-owned ball
returns to spatial positioning. Never infer possession from distance alone.
gotBall.wav is also centred; other alerts retain actual target positions.

## eFootAccess implementation

- `gameplay_camera.lua`: pure camera/body basis selection and validation.
- `gameplay_adapter.lua`: internal reads, emitting plain vectors/names.
- `gameplay.lua`: listener-relative transforms and owned-ball centring.
- `gameplay_runtime.lua`: 50 ms updates and complete snapshots.
- `AudioBridge.cs`: mono PCM16 WAV, OpenAL Soft 1.25.2, requested HRTF.

Reflected getters:

```text
MatchDataStore:GetMatchCameraType() -> EMatchCameraType
MatchDataStore:GetCameraType() -> EPesCameraType
GameplayStatics:GetPlayerCameraManager(WorldContextObject, 0)
PlayerCameraManager:GetCameraRotation() -> FRotator
```

Actual enum names are compared. EMatchCameraType::Player or effective
EPesCameraType::Player selects body direction; other recognized types use yaw.
Observed version: Player=9 in both enums, DynamicWide=Match4, Wide=Pes4. Do not
carry these numeric values into another game.

Production world context is the selected actor in the match world. MatchStatus
is an EngineSubsystem and returned no camera when used as world context. Local
index 0 matches the tested scenario; split-screen needs correct viewport mapping.

Observed eFootball meshes face local +Y while root forward comes from +X; adapter
converts accordingly. This is game-specific: verify another game's actual
mesh/head axes before copying. No camera/actor UObject or raw pointer survives
between updates, only plain metadata, numbers, names and paths. eFootball's
version-locked native ball/selection layout is not part of this portable math.

## Validation and adaptation checks

Actual Dynamic Wide capture: Match4/Pes4, yaw about -89.956°, pitch about -21.471°.
Live log confirmed camera orientation during play; HRTF status was 1. User said
it seemed to work and accepted keeping it. This does not separately certify
every view, half-time change or situation.

Test through normal play with sources right/left/ahead/behind. Turn the athlete
in general view, then test Player view. Check camera switching, half-time, pause
and resume. Keep internal readings, backend acceptance and user-confirmed hearing
distinct. Vector tests do not replace listening tests.
