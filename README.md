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

`CHANGELOG.md` dokumentuje rozwój V1–V25, `PROJECT_STATE.md` zawiera bieżące parametry techniczne i punkty bezpieczeństwa, `VERSIONING.md` opisuje przejście na nową numerację i zasady zachowania tożsamości moda, a `BINARY_ASSETS.md` pozostaje manifestem kontrolnym pochodzenia, rozmiarów i SHA-256 binariów.

## Budowanie moda

Builder używa dokładnej allowlisty plików gry z testowanego V25, dzięki czemu do ZIP-a nie trafiają `.git`, dokumentacja, narzędzia ani inne pliki repozytorium.

Weryfikacja bazowego V25:

```bash
python3 tools/verify_v25.py
```

Budowanie ZIP-a:

```bash
./build.sh
```

Wynik trafia do `dist/`. Dla obecnej historycznej bazy V25 domyślna nazwa nadal odpowiada release'owi V25.

Referencja testowanego V25 znajduje się w `reference/v25/`: `files.txt` zawiera 67 plików gry, a `SHA256SUMS.txt` ich kontrolne SHA-256.

## Google Drive

Google Drive pozostaje archiwum wcześniejszych buildów i oryginalnych plików źródłowych.

Folder projektu: `FS25mods/Ursus 1654 1954`

Folder ID: `1b1HHptqkSa0JwwYYPS2ZiDIMcFI4C25a`

Oryginał FS22: `FS22_Ursus_1654_1954_Pack_ORIGINAL.zip`

SHA-256 oryginalnego ZIP-a:
`6e74ef00d15c8d685b8f24d3c3c588d60854998a3241b5fe5f29e0e2c8a4d2e5`

## Workflow

1. `main` jest stabilną bazą ostatniej potwierdzonej wersji.
2. Kolejne poprawki robimy jako małe, czytelne commity/diffy.
3. Gotowe i testowe buildy publikujemy przez GitHub Releases; Google Drive nie jest już wymagany do bieżącej pracy.
4. Po potwierdzeniu testu aktualizujemy `CHANGELOG.md`, `PROJECT_STATE.md` i numer wersji.

## Kolejne prace przed zmianą numeracji

1. poprawa wyglądu powierzchni włączonych świateł / emissive,
2. obniżenie pozycji modelu kierowcy o kilka centymetrów — obecnie postać lewituje nad fotelem, a jej głowa wchodzi w sufit,
3. finalny przegląd logu i cleanup.

Po ukończeniu i przetestowaniu tych trzech punktów przechodzimy z historycznej numeracji `Vxx` na nową czteroczłonową semantykę podobną do GIANTS. Pierwszy build w nowej numeracji będzie miał wersję **`1.0.1.0`**.

Od `1.0.1.0` wszystkie wydania będą używać wyłącznie nowej semantyki, a gotowy plik moda będzie zawsze miał stałą nazwę:

`FS25_Ursus_1654_1954_Pack.zip`

Wersja będzie zapisywana w `modDesc.xml`, tagu Git i GitHub Release, ale nie w nazwie ZIP-a. Ma to zachować stałą tożsamość moda dla istniejących save'ów i zakupionych ciągników. Szczegóły: `VERSIONING.md`.
