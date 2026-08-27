# Ursus 1654–1954 — FS22 → FS25

Prywatne repo robocze konwersji moda Ursus 1654–1954 do Farming Simulator 25.

## Stan

Aktualna baza robocza: **V25 COLLISION SAFE**.

Najważniejsze punkty bezpieczeństwa:
- **V23 GEAR SAFE** — stabilny punkt powrotu dla silnika/skrzyni.
- **V24B HIGH/LOW SEQUENTIAL** — działająca skrzynia 8F/4R × L/H.
- **V25 COLLISION SAFE** — V24B + prawidłowe filtry kolizji FS25; potwierdzone w grze.
- Lusterka są zamknięte od V21 i nie należy zmieniać ich geometrii/rotacji bez wyraźnej potrzeby.

## Zawartość repo

Repo zawiera kompletny stan moda na **V25**, łącznie z plikami `.xml`, `.i3d`, `.lua`, lokalnym shaderem kompatybilności oraz statycznymi binariami (`.dds`, `.ogg`, `.wav`, `.i3d.shapes`). Po zwykłym `git clone` nie trzeba już ręcznie uzupełniać assetów z oryginalnego ZIP-a.

`CHANGELOG.md` dokumentuje rozwój V1–V25, `PROJECT_STATE.md` zawiera bieżące parametry techniczne i punkty bezpieczeństwa, a `BINARY_ASSETS.md` pozostaje manifestem kontrolnym pochodzenia, rozmiarów i SHA-256 binariów.

## Google Drive

Folder projektu: `FS25mods/Ursus 1654 1954`

Folder ID: `1b1HHptqkSa0JwwYYPS2ZiDIMcFI4C25a`

Oryginał FS22: `FS22_Ursus_1654_1954_Pack_ORIGINAL.zip`

SHA-256 oryginalnego ZIP-a:
`6e74ef00d15c8d685b8f24d3c3c588d60854998a3241b5fe5f29e0e2c8a4d2e5`

## Workflow od V26

1. `main` jest stabilną bazą ostatniej potwierdzonej wersji.
2. Kolejne poprawki robimy jako małe, czytelne commity/diffy.
3. Po zbudowaniu wersji testowej ZIP nadal trafia do folderu projektu na Google Drive.
4. Po potwierdzeniu testu aktualizujemy `CHANGELOG.md`, `PROJECT_STATE.md` i numer wersji.

## Kolejne prace

1. poprawa wyglądu powierzchni włączonych świateł / emissive,
2. obniżenie wyłącznie kamery zewnętrznej,
3. finalny przegląd logu i cleanup.
