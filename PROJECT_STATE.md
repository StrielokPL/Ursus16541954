# Project state — 1.0.5.1

Current stable baseline is **1.0.5.1**. The historical conversion numbering V1–V25 is closed; all future releases use the four-part version scheme.

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

Current version: **1.0.5.1**.

Stable downloadable ZIP name from this version onward:

`FS25_Ursus_1654_1954_Pack.zip`

Do not rename `Ursus1934.xml`, `Weight2500kg.xml`, their store-item paths or other identity-bearing paths without an explicit savegame migration plan. See `VERSIONING.md`.

## Validation / build

`./build.sh` now runs `tools/validate_current.py` before building. The validator checks the 67-file game allowlist, parses all XML/I3D files, confirms the `A.B.C.D[K][N]` version form, store-item paths, transmission script reference and stable ZIP naming.

The historical exact V25 SHA manifest remains under `reference/v25/` as a regression/reference point; it is not the current-release hash manifest.

## Runtime note

Version 1.0.4.1 was verified in Farming Simulator 25. Refuelling, the 2500 kg weight AI outline, lights and dashboards retain their approved behavior. The optional Advanced Damage System bridge and load-aware automatic transmission were runtime-tested through T1–T4, including an extreme high-load plowing test in rain at 100% soil wetness. The final test log contains no Ursus-related Lua errors.

Known accepted issue: `Ursus1934.i3d` still reports `i3d contains non-binary indexed triangle sets` for the inline `FS25MirrorExact` geometry. This non-fatal storage/performance-format warning has no observed gameplay or visual effect. Converting it to binary `.i3d.shapes` is deferred because that asset change requires a new regression test of the approved mirrors.


### Full color palette / custom RGB — 1.0.5.0T4
- Nadwozie i felgi: niezależne konfiguracje z `useDefaultColors=true`.
- Pełna paleta GIANTS i picker RGB są obsługiwane przez `VehicleConfigurationItemColor`.
- `UrsusColorFix.lua` nakłada faktyczny RGB na whitelistę kształtów legacy I3D.
- Obciążniki kół, lampy, hydraulika i kalkomanie pozostają poza kolorowaniem.
- F5 to globalny debug-renderer GIANTS, nie funkcja Ursusa; wyłączenie per-mod wymagałoby usunięcia aktywnych kolizji.


### T4 packaging hotfix — 1.0.5.0T4
- `UrsusColorFix.lua` jest częścią ZIP allowlisty.
- Walidator wymusza obecność wszystkich `extraSourceFiles` w paczce.
- Log T3 potwierdził, że brak tego pliku w ZIP powodował `Can't load resource` i wyłączał runtime bridge kolorów.


### T5 roof hatch color fix — 1.0.5.0T5
- `SzyberDach/szyber` jest objęty kolorem nadwozia.
- Pozostałe części grupy `SzyberDach` pozostają bez zmian.
- T5 jest izolowaną poprawką whitelisty `UrsusColorFix`; brak zmian w fizyce i skrzyni.


## Color configuration — stable 1.0.5.1
- Nadwozie i felgi mają niezależne konfiguracje kolorów z pełną paletą GIANTS i własnym RGB.
- Runtime bridge `UrsusColorFix.lua` obsługuje legacy materiały I3D bez ingerencji w fizykę pojazdu.
- Klapa dachowa `SzyberDach/szyber` jest objęta kolorem nadwozia; rama, uszczelki i mechanizm pozostają bez zmian.
- `UrsusColorFix.lua` jest obowiązkowo walidowany jako `extraSourceFile` i pakowany do ZIP.
- T5 został potwierdzony wizualnie i logowo; brak nowych błędów związanych z Ursusem.


### Widmo wheelie physics test — 1.0.6.0T1
- Bazą pozostaje stabilne 1.0.5.1.
- `1934 Robert` otrzymał nazwę sklepową `1934 Widmo`.
- Wyłącznie Widmo: `centerOfMassActive="0 1.05 -1.25"` na głównym komponencie.
- T1 nie używa skryptowego momentu ani siły; sprawdza tylko naturalną fizykę pod dużym obciążeniem.
- Jeżeli efekt będzie zbyt mały, następny test może zwiększyć przesunięcie albo dodać warunkowy fizyczny assist.


### Widmo wheelie physics test — 1.0.6.0T2
- T1 nie podnosił przodu nawet z dużą masą z tyłu.
- Widmo korzysta teraz z pełnej charakterystyki `1934 Chip` (225 KM, torqueScale 0.850).
- Wyłącznie Widmo: `centerOfMassActive="0 1.05 -1.65"`.
- T2 nadal nie używa skryptowego momentu ani siły.


### Widmo drivetrain test — 1.0.6.0T3
- Widmo nadal: 225 KM z dokładnym blokiem silnika 1934 Chip i `centerOfMassActive="0 1.05 -1.65"`.
- T3 przełącza wyłącznie Widmo na RWD przed zbudowaniem fizycznych dyferencjałów; pozostaje tylko tylny dyferencjał.
- Pozostałe silniki zachowują 4x4.
- Cel: odizolować wpływ centralnego dyferencjału 50/50 na możliwość odciążenia/podniesienia przedniej osi.


### Widmo wheelie physics test — 1.0.6.0T4
- T3 RWD był bardzo blisko uniesienia przodu, ale ciągnik tylko wolniej ruszał.
- Widmo nadal RWD, 225 KM z 1934 Chip, COM Z pozostaje -1.65.
- COM Y podniesiono do 1.40.
- Tylne koła Widma: forcePointRatio 0.80; pozostałe koła/wersje bez zmian.
- T4 jest ostatnim testem czystej fizyki przed ewentualnym lekkim warunkowym addTorque.


### Widmo balance/torque test — 1.0.6.0T5
- T4 potrafi unieść przód z ciężkim pługiem, ale przy skręcie około 20 km/h odrywa wewnętrzne tylne koło.
- T5: COM `0 1.10 -1.80`, RWD i rear forcePointRatio 0.80.
- Widmo: 265 KM, torqueScale 1.000, ta sama krzywa momentu co T4/Chip.
- Cel: zachować wheelie pod dużym obciążeniem przy wyraźnie lepszej stabilności bocznej.


### Widmo direct 8/4 gearbox test — 1.0.6.0T6
- Wyłącznie `1934 Widmo`: własna bezpośrednia skrzynia 8F/4R bez grup L/H.
- Parametry T5 pozostają: 265 KM, torqueScale 1.000, RWD, COM `0 1.10 -1.80`, rear forcePointRatio 0.80.
- Pozostałe warianty nadal używają 8F/4R × L/H oraz istniejącego bridge ADS.


### Widmo torque/longitudinal traction test — 1.0.6.0T7
- T6: direct 8F/4R only for Widmo; trailer tests came close to lifting the front.
- T7 increases only Widmo engine torque by 10% (`torqueScale=1.100`, 290 hp store value).
- Rear WheelPhysics only: `maxLongStiffness` x1.20; lateral stiffness and overall friction scale unchanged to avoid worsening cornering wheel lift.
- RWD, COM `0 1.10 -1.80`, rear forcePointRatio 0.80 and direct 8F/4R retained.


### Widmo manual drivetrain toggle — 1.0.6.0T8
- T7 produced a clean wheelie when the loaded trailer set hung on an obstacle; no further COM change is made.
- Only `1934 Widmo`: manual RWD/4x4 input action, default `Ctrl+4`, remappable in FS25 controls.
- Default/load state is RWD. 4x4 restores the original front, rear and centre differential definitions; RWD keeps only the rear differential.
- The authoritative differential rebuild happens server-side and the selected state is broadcast to clients.
- T7 tuning remains unchanged: 290 hp, torqueScale 1.100, direct 8F/4R, COM `0 1.10 -1.80`, rear forcePointRatio 0.80 and rear maxLongStiffness x1.20.


### Front ballast physics fix — 1.0.6.0T9
- Koła i ich konfiguracje pozostają nietknięte.
- Legacy mass/COM objectChanges 600/1200/1500/2000 kg zostały usunięte z attacherJointConfigurations.
- Front ballast jest dodawany do komponentu #1: bazowo 3700 kg + nominalna masa balastu.
- Bazowy COM: standard `0 0.80 -0.88`; Widmo `0 1.10 -1.80`.
- Punkty masy balastu: 600/1200 kg `0 0.65 2.45`; 1500/2000 kg `0 0.70 2.65`. Wynikowy COM jest liczony jako średnia ważona.
- FrameWeight-only oraz FrontHydraulic nie dostają dodatkowej masy w T9; poprawka dotyczy nominalnych pakietów 600/1200/1500/2000 kg.
- T8 drivetrain toggle i całe strojenie Widma pozostają bez zmian.


### Widmo rear lateral grip test — 1.0.6.0T10
- User confirmed T9 front ballast physics works.
- Only rear wheels of `1934 Widmo`: maxLatStiffness multiplied by 0.85 at WheelPhysics load.
- Rear maxLongStiffness x1.20 and forcePointRatio 0.80 remain unchanged.
- No wheel XML files changed.
- Purpose: reduce rollover tendency in corners by allowing earlier lateral rear slip while preserving launch traction/wheelie behavior.
- T9 ballast physics, T8 manual RWD/4x4, 290 hp, direct 8F/4R and COM remain unchanged.


### Widmo rear dynamic suspension / power-hop test — 1.0.6.0T11
- T10 prowadzi się nieco lepiej po zmniejszeniu bocznej sztywności tylnej osi.
- T11 nie używa sztucznych sił. Hook `Wheel:update` po aktualizacji koła #4 mierzy load kół #3/#4 i stosuje natywne `setSuspensionMultipliers()` dla tylnej pary.
- Zakres: axleLoad rest -> 1.60x rest; spring 1.00 -> 1.15; damping 1.00 -> 0.60; interpolacja 500 ms.
- Cel: sprawdzić, czy pod dużym obciążeniem i dużym momentem Widmo zacznie naturalnie odbijać/power-hopować na tylnych oponach.
- T10/T9/T8 zachowane bez zmian; `wheels/` i `Ursus1934.xml` bez zmian.


### Whole-family dynamic tire/suspension response — 1.0.6.0T12
- T11 rear load-driven suspension response expanded from Widmo to every Ursus motor/wheel configuration.
- Rear: max-load factor 1.60, spring 1.15, damping 0.60, interpolation 500 ms.
- Front: milder max-load factor 1.50, spring 1.10, damping 0.75, interpolation 450 ms.
- Uses native WheelPhysics suspension multipliers only; no impulse/force simulation.
- Widmo-specific traction tuning remains separate and unchanged.
- Wheel XML and Ursus1934.xml unchanged in T12.


### Store transmission/drivetrain + mass diagnostic — 1.0.6.0T13
- Native unused `design2` selector is used as `Skrzynia biegów`: factory 8/4×L/H or no-booster direct 8/4.
- Native unused `design3` selector is used as `Układ napędowy`: factory 4x4 or front axle disconnected (RWD).
- Widmo Ctrl+4 remains available; store drivetrain choice determines its initial state.
- Mass diagnostic emits `[UrsusMassDiag]` lines after ~2.5 s stationary: four tire loads, front/rear percentage, total/raw axle load, component mass/COM and wheel mass.
- Purpose: collect real in-game axle split before changing standard tractor component masses/COM.
- No T13 mass/COM change. Widmo mass layout is explicitly frozen for this diagnostic stage.
