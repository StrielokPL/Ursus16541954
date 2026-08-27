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

## Pending before semantic-version baseline
- emitted lamp surfaces are too white when switched on,
- driver character model is positioned several centimetres too high: it floats above the seat and the head intersects the roof; this is a driver-position issue, not a camera-height issue,
- final log review and cleanup.

## Planned version transition
After all three pending items above are completed and tested, the project leaves the historical conversion numbering (`V1`–`V25`) and adopts the new GIANTS-like four-part version scheme.

The first release in the new scheme will be **`1.0.1.0`**.

From that point onward:
- only the new four-part version scheme is used for releases and `modDesc.xml`,
- legacy `Vxx` labels remain only as historical references,
- release ZIP filename remains constant across upgrades so an existing save sees the new package as the same mod,
- vehicle/store XML filenames and mod identity paths must remain stable unless an explicit migration is designed.

See `VERSIONING.md` for the complete policy.
