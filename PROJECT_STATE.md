# Project state — V25 COLLISION SAFE

Current working baseline is V25. Mirrors, engine curves, transmission and collisions are considered closed unless a new regression is found.

## Mirrors
Final rotations (do not change for simple in/out adjustment):
- MirrorL: `-3.272027990 2.511693300 12.415270590`
- MirrorP: `-3.088065090 2.579479800 12.954543890`

Indoor camera (Kabina-local): `(0, 1.01023, -0.839)`.

For small 1 cm movements toward camera, child translation deltas from the current position are approximately:
- MirrorL: `(-0.00590174, +0.00807091, -0.00017263)`
- MirrorP: `(+0.00178997, +0.00982288, -0.00055404)`
Reverse signs to move away from camera.

## Transmission
8F/4R × Low/High, POWERSHIFT splitter. Automatic virtual order: `1L → 1H → 2L → 2H ...`; reverse uses the same logic.

## Collisions
Native FS25 filter values used by the tractor and weight:
- `collisionFilterGroup="0x10004"`
- `collisionFilterMask="0xfe3ffb83"`

AI collision trigger: `<collisionTrigger useSize="true"/>`.

## Pending
- emitted lamp surfaces are too white when switched on,
- external camera is slightly too high,
- final log/cleanup.
