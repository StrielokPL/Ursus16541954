# Project state — 1.0.4.1

Current stable baseline is **1.0.4.1**. The historical conversion numbering V1–V25 is closed; all future releases use the four-part version scheme.

## Closed / confirmed areas

- mirrors: final since V21,
- engine curves and actual power,
- transmission: 8F/4R × Low/High, POWERSHIFT splitter with automatic virtual order `1L → 1H → 2L → 2H ...`, same logic forward and reverse,
- wheels and configurations,
- front/rear hydraulics and animations,
- interactive doors, roof and rear window,
- native FS25 collisions,
- light emissive appearance,
- driver character vertical position,
- rear pin hitch height range and rear PTO routing,
- 2500 kg weight AI attachment outline,
- exact diesel fill root area,
- dead light and dashboard emitter mappings removed without visual changes.

## Mirrors

Final rotations (do not change for simple in/out adjustment):
- MirrorL: `-3.272027990 2.511693300 12.415270590`
- MirrorP: `-3.088065090 2.579479800 12.954543890`

Indoor camera (Kabina-local): `(0, 1.01023, -0.839)`.

For small 1 cm movements toward camera, child translation deltas from the current position are approximately:
- MirrorL: `(-0.00590174, +0.00807091, -0.00017263)`
- MirrorP: `(+0.00178997, +0.00982288, -0.00055404)`

Reverse signs to move away from camera.

## Rear hitch and PTO

- upper adjustable pin hitch: `jointType="trailer"`, range `Y 0.760–1.040`,
- lower fixed ball hitch: `jointType="trailerLow"`,
- rear PTO output remains assigned to attacher joint indices `1 2 3`,
- front PTO output remains assigned to attacher joint index `4`.

## Collisions

Native FS25 collision state:
- the tractor root uses `collisionFilterGroup="0x40010004"`; bit 30 `FILLABLE` is required by the fuel trigger,
- the approved collision mask remains `collisionFilterMask="0xfe3ffb83"`,
- the hood collision is aligned with the visual tractor outline,
- front equipment collision is configuration-dependent: wide FrameWeight/1200/2000 kg family, narrow FrameWeight(2)/600/1500 kg family, separate TUZ, or no added collision,
- all weight-family boxes are 5 cm lower than the preceding test; the wide family is spread to x = ±0.20 m,
- the 2500 kg weight defines `<agentAttachment useSize="true"/>` for its AI outline,
- the tractor has a separate non-renderable FILLABLE box `exactFillRootNodeFuel` at `0>11|7`, assigned only to the diesel fill unit.

AI collision trigger: `<collisionTrigger useSize="true"/>`.

## Lights

The local `staticLight` compatibility shader keeps the original vertex-color lamp colors but scales emissive surface output to 40% and applies a subtle warm multiplier `1.0 0.88 0.72`. Actual light-node power, beam distance and direction are unchanged.

Version 1.0.3.0 removes one rejected `defaultLight` mapping and five rejected dashboard `EMITTER` mappings. No light geometry, shader, emissive texture, brightness, color or valid light behavior was changed; runtime appearance was confirmed unchanged.

## Driver character

`characterNode` points to `playerRoot` (`nodeId=496`). In 1.0.1.0 its local translation is:

`-1.0516e-14 -0.06 0`

This is 6 cm lower than V25. Cameras, seat geometry and IK targets were not moved.

## Realism / ADS compatibility

Stable 1.0.4.1 adds optional integration without making Advanced Damage System a hard dependency:
- Vehicle Years receives store year `2009`,
- diesel capacity is `355 l`,
- automatic L/H changes respect ADS gear-shift failure and powershift lag effects,
- while ADS is active the automatic load guard reads `spec.dynamicMotorLoad`,
- at >80% load it downshifts below 65% max RPM and blocks upshifts below 83% max RPM,
- protective downshifts are one virtual step at a time with a 1.8 s post-downshift upshift hold,
- without ADS and in manual mode the approved transmission behavior is unchanged.

## Package identity

Current version: **1.0.4.1**.

Stable downloadable ZIP name from this version onward:

`FS25_Ursus_1654_1954_Pack.zip`

Do not rename `Ursus1934.xml`, `Weight2500kg.xml`, their store-item paths or other identity-bearing paths without an explicit savegame migration plan. See `VERSIONING.md`.

## Validation / build

`./build.sh` now runs `tools/validate_current.py` before building. The validator checks the 67-file game allowlist, parses all XML/I3D files, confirms the `A.B.C.D[K][N]` version form, store-item paths, transmission script reference and stable ZIP naming.

The historical exact V25 SHA manifest remains under `reference/v25/` as a regression/reference point; it is not the current-release hash manifest.

## Runtime note

Version 1.0.4.1 was verified in Farming Simulator 25. Refuelling, the 2500 kg weight AI outline, lights and dashboards retain their approved behavior. The optional Advanced Damage System bridge and load-aware automatic transmission were runtime-tested through T1–T4, including an extreme high-load plowing test in rain at 100% soil wetness. The final test log contains no Ursus-related Lua errors.

Known accepted issue: `Ursus1934.i3d` still reports `i3d contains non-binary indexed triangle sets` for the inline `FS25MirrorExact` geometry. This non-fatal storage/performance-format warning has no observed gameplay or visual effect. Converting it to binary `.i3d.shapes` is deferred because that asset change requires a new regression test of the approved mirrors.


### Full color palette / custom RGB — 1.0.5.0T3
- Nadwozie i felgi: niezależne konfiguracje z `useDefaultColors=true`.
- Pełna paleta GIANTS i picker RGB są obsługiwane przez `VehicleConfigurationItemColor`.
- `UrsusColorFix.lua` nakłada faktyczny RGB na whitelistę kształtów legacy I3D.
- Obciążniki kół, lampy, hydraulika i kalkomanie pozostają poza kolorowaniem.
- F5 to globalny debug-renderer GIANTS, nie funkcja Ursusa; wyłączenie per-mod wymagałoby usunięcia aktywnych kolizji.
