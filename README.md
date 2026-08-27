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

Repo odtwarza edytowalny stan moda na V25 i zawiera changelog V1–V25. Wszystkie edytowalne pliki moda (`.xml`, `.i3d`, `.lua`) oraz lokalny shader kompatybilności są wersjonowane bezpośrednio w Git.

Duże statyczne binaria (`.dds`, `.ogg`, `.wav`, `.i3d.shapes`) pochodzą z oryginalnego ZIP-a FS22. Ze względu na ograniczenia konektora GitHub dla lokalnych plików binarnych są opisane w `BINARY_ASSETS.md` wraz z SHA-256 i ścieżkami źródłowymi. Skrypt `tools/hydrate_binary_assets.py` odtwarza je z oryginalnego ZIP-a.

## Google Drive

Folder projektu: `FS25mods/Ursus 1654 1954`

Folder ID: `1b1HHptqkSa0JwwYYPS2ZiDIMcFI4C25a`

Oryginał FS22: `FS22_Ursus_1654_1954_Pack_ORIGINAL.zip`

SHA-256 oryginalnego ZIP-a:
`6e74ef00d15c8d685b8f24d3c3c588d60854998a3241b5fe5f29e0e2c8a4d2e5`

## Kolejne prace

1. poprawa wyglądu powierzchni włączonych świateł / emissive,
2. obniżenie wyłącznie kamery zewnętrznej,
3. finalny przegląd logu i cleanup.
