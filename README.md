# Ursus 1654–1954 — FS22 → FS25

Prywatne repo robocze konwersji moda Ursus 1654–1954 do Farming Simulator 25.

## Stan

Aktualna stabilna wersja: **1.0.2.2**.

Historyczne punkty bezpieczeństwa:
- **V23 GEAR SAFE** — stabilny punkt powrotu dla silnika/skrzyni,
- **V24B HIGH/LOW SEQUENTIAL** — działająca skrzynia 8F/4R × L/H,
- **V25 COLLISION SAFE** — prawidłowe filtry kolizji FS25,
- **1.0.1.0** — pierwszy kompletny baseline po zamknięciu konwersji i przejściu na nową numerację.
- **1.0.2.0** — zatwierdzony cleanup FS25, działające tankowanie oraz finalne kolizje wariantów przedniego wyposażenia.
- **1.0.2.2** — regulowany górny zaczep na pin z zakresem pozwalającym zejść poniżej tylnego WOM-u.

Lusterka są zamknięte od V21 i nie należy zmieniać ich geometrii/rotacji bez wyraźnej potrzeby.

## 1.0.1.0

Względem V25:
- poprawiono emissive powierzchni włączonych lamp,
- model kierowcy obniżono łącznie o 6 cm bez ruszania kamer, fotela i targetów IK,
- wykonano cleanup builda i walidację struktury moda,
- wprowadzono nową czteroczłonową semantykę wersji.

Od tej wersji plik moda ma stałą nazwę:

`FS25_Ursus_1654_1954_Pack.zip`

Numer wersji znajduje się w `modDesc.xml`, pliku `VERSION`, tagu Git i GitHub Release, ale nie w nazwie ZIP-a. Ma to utrzymać stałą tożsamość moda dla istniejących save'ów i zakupionych ciągników.

## 1.0.2.0

Względem 1.0.1.0:
- usunięto martwe referencje materiałów i przestarzałe wpisy dźwięków generujące błędy logu,
- dostosowano XML obciążnika 2500 kg do schematu FS25,
- przywrócono prawidłowe wykrywanie ciągnika przez trigger tankowania,
- przedni TUZ, WOM, przewody i punkty podpinania są aktywne tylko we właściwej konfiguracji,
- skorygowano główną kolizję maski i dodano osobne, dopasowane kolizje dla rodzin przednich ram, obciążników i TUZ-a,
- brak przedniego wyposażenia nie dodaje dodatkowego boxa kolizji.

Tankowanie oraz kolizje wszystkich wariantów zostały potwierdzone w grze na buildzie CLEANUP TEST 24.

## 1.0.2.2

Względem 1.0.2.0:
- rozszerzono regulację wysokości górnego zaczepu na pin do zakresu `Y 0.760–1.040`,
- dolny, nieruchomy zaczep kulowy `trailerLow` pozostał bez zmian,
- zachowano indeksy tylnego WOM-u `1 2 3` i przedniego WOM-u `4`,
- wprowadzono walidację wersji w formacie `A.B.C.D[K][N]` oraz opisano znaczenie sufiksów `H/F/T/P`.

## Zawartość repo

Repo zawiera kompletny stan moda, łącznie z `.xml`, `.i3d`, `.lua`, lokalnym shaderem kompatybilności oraz statycznymi binariami (`.dds`, `.ogg`, `.wav`, `.i3d.shapes`). Po zwykłym `git clone` nie trzeba uzupełniać assetów z oryginalnego ZIP-a.

`CHANGELOG.md` dokumentuje historię V1–V25 oraz stabilne wydania 1.0.1.0, 1.0.2.0 i 1.0.2.2. `PROJECT_STATE.md` zawiera bieżące parametry techniczne i punkty bezpieczeństwa. `VERSIONING.md` opisuje zasady dalszego wersjonowania i zachowania tożsamości moda.

## Walidacja i budowanie

Bieżąca walidacja:

```bash
python3 tools/validate_current.py
```

Budowanie:

```bash
./build.sh
```

`build.sh` automatycznie uruchamia walidator przed zbudowaniem paczki. Wynik trafia do:

`dist/FS25_Ursus_1654_1954_Pack.zip`

Builder używa kontrolowanej 67-plikowej allowlisty, dzięki czemu do ZIP-a nie trafiają `.git`, dokumentacja, narzędzia ani pliki robocze repozytorium.

Historyczna referencja dokładnego V25 znajduje się w `reference/v25/`. `files.txt` jest nadal bazową listą 67 plików gry, natomiast `SHA256SUMS.txt` opisuje wyłącznie historyczny V25 i nie jest manifestem bieżącej wersji.

## Releases

Gotowe buildy pobieramy z GitHub Releases. Stabilne wydania używają tagów w formie np. `v1.0.1.0`, a asset moda zachowuje stałą nazwę `FS25_Ursus_1654_1954_Pack.zip`.

Google Drive pozostaje tylko archiwum wcześniejszych buildów i oryginalnych plików źródłowych.

## Workflow rozwoju

1. `main` jest stabilną bazą ostatniego zaakceptowanego wydania.
2. Zmiany robimy jako małe, czytelne commity/diffy i testujemy na osobnych buildach/pre-release'ach, gdy jest to potrzebne.
3. Po akceptacji aktualizujemy numer wersji, changelog i publikujemy GitHub Release.
4. Od 1.0.1.0 nie wracamy do numeracji `V26`, `V27` itd.; używamy wyłącznie czteroczłonowej numeracji opisanej w `VERSIONING.md`.
