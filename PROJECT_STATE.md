# Project state — 1.0.1.0

Current stable baseline is **1.0.1.0**. The historical conversion numbering V1–V25 is closed; all future releases use the four-part version scheme.

## Closed / confirmed areas

- mirrors: final since V21,
- engine curves and actual power,
- transmission: 8F/4R × Low/High, POWERSHIFT splitter with automatic virtual order `1L → 1H → 2L → 2H ...`, same logic forward and reverse,
- wheels and configurations,
- front/rear hydraulics and animations,
- interactive doors, roof and rear window,
- native FS25 collisions,
- light emissive appearance,
- driver character vertical position.

## Mirrors

Final rotations (do not change for simple in/out adjustment):
- MirrorL: `-3.272027990 2.511693300 12.415270590`
- MirrorP: `-3.088065090 2.579479800 12.954543890`

Indoor camera (Kabina-local): `(0, 1.01023, -0.839)`.

For small 1 cm movements toward camera, child translation deltas from the current position are approximately:
- MirrorL: `(-0.00590174, +0.00807091, -0.00017263)`
- MirrorP: `(+0.00178997, +0.00982288, -0.00055404)`

Reverse signs to move away from camera.

## Collisions

Native FS25 filter values used by the tractor and weight:
- `collisionFilterGroup="0x10004"`
- `collisionFilterMask="0xfe3ffb83"`

AI collision trigger: `<collisionTrigger useSize="true"/>`.

## Lights

The local `staticLight` compatibility shader keeps the original vertex-color lamp colors but scales emissive surface output to 40% and applies a subtle warm multiplier `1.0 0.88 0.72`. Actual light-node power, beam distance and direction are unchanged.

## Driver character

`characterNode` points to `playerRoot` (`nodeId=496`). In 1.0.1.0 its local translation is:

`-1.0516e-14 -0.06 0`

This is 6 cm lower than V25. Cameras, seat geometry and IK targets were not moved.

## Package identity

Current version: **1.0.1.0**.

Stable downloadable ZIP name from this version onward:

`FS25_Ursus_1654_1954_Pack.zip`

Do not rename `Ursus1934.xml`, `Weight2500kg.xml`, their store-item paths or other identity-bearing paths without an explicit savegame migration plan. See `VERSIONING.md`.

## Validation / build

`./build.sh` now runs `tools/validate_current.py` before building. The validator checks the 67-file game allowlist, parses all XML/I3D files, confirms the four-part version, store-item paths, transmission script reference and stable ZIP naming.

The historical exact V25 SHA manifest remains under `reference/v25/` as a regression/reference point; it is not the current-release hash manifest.

## Runtime note

Repository/package validation cannot replace a Farming Simulator runtime log. A fresh FS25 log was not stored in this repository at the time of the 1.0.1.0 release; if a runtime warning is later found, treat it as a normal follow-up fix under the new version scheme.
