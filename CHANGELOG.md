# Changelog konwersji FS22 → FS25

## Punkty bezpieczeństwa
- **V23 GEAR SAFE** — stabilna skrzynia 16F/8R + lokalny limiter automatu.
- **V24B HIGH/LOW SEQUENTIAL** — działająca skrzynia 8F/4R × L/H.
- **V25 COLLISION SAFE** — prawidłowe kolizje FS25; historyczny ostatni baseline numeracji Vxx.
- **1.0.1.0** — pierwszy stabilny baseline nowej czteroczłonowej numeracji.

## Wersje historyczne V1–V25
- **V1** — pierwsza uruchamialna konwersja FS25; sklep, geometria, silniki, hydraulika i animacje działały; shader i opony wymagały naprawy.
- **V2** — próba `$data/fs22support/shaders/vehicleShader.xml`; nieudana, większość ciągnika niewidoczna.
- **V3** — lokalny shader kompatybilności; materiały naprawione; drzwi/dach/tylna szyba działają.
- **V4** — natywne assety opon FS25; opony zamknięte jako działające.
- **V5** — rejestracja `<mirrors>`; bez poprawy kierunku odbicia.
- **V6** — rozdzielenie materiałów lewego/prawego lustra.
- **V7** — osobne parent TransformGroup dla lusterek.
- **V8** — test nowej prostokątnej tafli refleksyjnej.
- **V9** — pierwszy przełom: odbicie zaczęło patrzeć do tyłu; płaszczyzny źle pozycjonowane.
- **V10** — korekta położenia tafli.
- **V11** — błędna korekta 30%; nie używać jako bazy.
- **V12** — ruch w stronę prawdziwej indoorCamera1.
- **V13** — pośrednia głębokość lusterek.
- **V14** — 10% dalej od kamery przy zachowaniu kierunku promienia.
- **V15** — podniesienie lusterek o 0.225 m.
- **V16** — diagnostyczny frame probe; nie finalny.
- **V17** — exact mirror plane: rozkodowany oryginalny `shapeId=132`; 20 vertices / 18 triangles.
- **V18** — test optycznej osi bez zmiany world plane; potwierdzono, że planar reflection zależy od faktycznej płaszczyzny w świecie.
- **V19** — fizyczna korekta kąta lusterek; finalne rotacje ustalone.
- **V20** — lustra +1 cm do kamery.
- **V21** — dodatkowe +1.5 cm do kamery; użytkownik potwierdził finalną pozycję lusterek.
- **V22** — prawidłowe krzywe momentu/mocy wszystkich silników + jawna skrzynia 16F/8R.
- **V23** — lokalny `UrsusTransmissionFix.lua`; ograniczenie zbyt wysokiego biegu startowego i dużych skoków; **GEAR SAFE**.
- **V24** — eksperymentalne 8F/4R + L/H `POWERSHIFT`; natywny automat wybierał L do przodu i H do tyłu — wersja błędna.
- **V24B** — lokalna sekwencja splittera `1L → 1H → 2L → 2H...`, identyczna dla przodu/tyłu; potwierdzona jako dobra.
- **V25** — konwersja starych masek kolizji FS22 na FS25: `collisionFilterGroup=0x10004`, `collisionFilterMask=0xfe3ffb83`; natywny `<collisionTrigger useSize="true"/>`; użytkownik potwierdził poprawne kolizje ze sprzętem i ruchem drogowym. **COLLISION SAFE**.

## 1.0.1.0
Pierwsze stabilne wydanie po zamknięciu numeracji konwersyjnej Vxx.

Zmiany względem V25:
- zaakceptowana poprawka powierzchni świecących lamp: emissive `staticLight` zmniejszony do 40% i lekko ocieplony mnożnikiem `1.0 0.88 0.72`; bez zmiany mocy/zasięgu faktycznych źródeł światła,
- poprawiona pozycja modelu kierowcy w TPP: `playerRoot` obniżony łącznie o 6 cm; kamery, fotel i targety IK pozostawione bez zmian,
- `modDesc.xml` przestawiony na wersję `1.0.1.0`,
- od tej wersji stabilna nazwa paczki to `FS25_Ursus_1654_1954_Pack.zip`,
- builder i walidacja uporządkowane pod dalszy rozwój,
- usunięto aktywny jednorazowy workflow wydania V25; historyczny Release V25 pozostaje zachowany.

## Dalszy rozwój
Od **1.0.1.0** używamy wyłącznie czteroczłonowej numeracji opisanej w `VERSIONING.md`. Numeracji V26/V27 nie stosujemy do nowych buildów.
