# Ursus 1654–1954 — Farming Simulator 25

Konwersja i dalszy rozwój moda **Ursus 1654–1954** z Farming Simulator 22 do Farming Simulator 25.

Repozytorium zawiera kompletny stan moda: XML, I3D, Lua, lokalne shadery kompatybilności oraz wymagane assety binarne. Po zwykłym `git clone` nie trzeba uzupełniać plików z oryginalnego ZIP-a.

## Aktualny stan

**Aktualna stabilna wersja: 1.1.1.0**

Stała nazwa paczki moda:

`FS25_Ursus_1654_1954_Pack.zip`

Numer wersji jest przechowywany w `modDesc.xml`, `VERSION`, tagu Git i GitHub Release, ale nie jest dopisywany do nazwy ZIP-a. Pozwala to zachować stałą tożsamość moda dla istniejących save'ów i zakupionych maszyn.

Wydanie 1.1.1.0 zamyka serię testową `1.0.6.0T1–T14` i wprowadza istotne zmiany fizyki masy, napędu i konfiguracji skrzyni. Z tego powodu nie jest traktowane jako w pełni zgodne zachowaniem z linią 1.0.x.

## Najważniejsze funkcje

### Konwersja FS25

- natywne filtry i maski kolizji FS25,
- poprawione kolizje maski oraz konfiguracji przednich ram, obciążników i TUZ-a,
- działające tankowanie z dokładnym obszarem `exactFillRootNodeFuel`,
- poprawny obrys AI obciążnika 2500 kg,
- przedni TUZ, WOM i przewody aktywne wyłącznie we właściwej konfiguracji,
- regulowany górny tylny zaczep na pin `Y 0.760–1.040`,
- zachowany dolny zaczep kulowy `trailerLow`,
- tylne wyjście WOM dla indeksów `1 2 3`, przednie dla indeksu `4`,
- działające drzwi, tylna szyba, klapa dachowa, hydraulika i pozostałe animacje,
- zatwierdzone lusterka FS25 — geometria i rotacje zamknięte od V21,
- oczyszczone mapowania świateł i zegarów bez zmiany ich prawidłowego działania.

### Skrzynia biegów

W sklepie można niezależnie wybrać konfigurację skrzyni:

| Konfiguracja | Układ | Dopłata |
| --- | --- | ---: |
| **Fabryczna** | 8F/4R × L/H = 16F/8R | 0 |
| **Bez wzmacniacza** | bezpośrednie 8F/4R | +5000 |

Fabryczna skrzynia korzysta z zatwierdzonej sekwencji powershift `1L → 1H → 2L → 2H ...`, identycznej dla jazdy do przodu i do tyłu.

Lokalny `UrsusTransmissionFix.lua` ogranicza nienaturalne wysokie biegi startowe i zbyt duże skoki automatu.

### Układ napędowy

W sklepie dostępny jest niezależny wybór napędu:

| Konfiguracja | Napęd | Dopłata |
| --- | --- | ---: |
| **Fabryczny** | 4x4 | 0 |
| **Odłączenie przedniej osi** | RWD | +2500 |

Dla wersji **1934 Widmo** dostępne jest dodatkowo ręczne przełączanie `RWD ↔ 4x4` podczas jazdy. Akcja `URSUS_WIDMO_TOGGLE_4WD` jest remapowalna w ustawieniach sterowania FS25; domyślnie używa `Ctrl+4`.

Przebudowa fizycznych dyferencjałów jest wykonywana po stronie serwera i synchronizowana z klientami.

Ręczny stan przełącznika Widma nie jest zapisywany osobno w savegame. Po ponownym wczytaniu pojazd rozpoczyna od stanu wynikającego z konfiguracji napędu wybranej w sklepie.

## Fizyka masy i balastów

### Zwykłe warianty

Bazowy układ komponentów:

- component #1: `3720 kg`,
- component #2: `1340 kg`,
- bazowy COM: `0 0.80 -0.88`.

Test runtime na podstawowych kołach i z pełnym zbiornikiem potwierdził około **6.183 t** masy roboczej oraz rozkład około **39.9% przód / 60.1% tył**.

### Przednie obciążniki

Pakiety `600 / 1200 / 1500 / 2000 kg` dodają rzeczywistą masę do głównego komponentu ciągnika. Wpływ obciążnika na środek masy jest liczony jako średnia ważona pomiędzy bazowym COM ciągnika i fizycznym położeniem balastu.

Dłuższe pakiety 1500/2000 kg mają punkt masy ustawiony dalej z przodu niż 600/1200 kg. Konfiguracje `FrameWeight` i `FrontHydraulic` bez nominalnego pakietu masy nie otrzymują sztucznej dodatkowej masy.

Masy kół pozostają obsługiwane natywnie przez system kół GIANTS i nie są sztucznie kompensowane przez skrypt ciągnika.

## Dynamiczne zawieszenie

Cała rodzina Ursusa korzysta z zależnej od obciążenia regulacji zawieszenia przez natywne `WheelPhysics:setSuspensionMultipliers()`.

Nie są używane sztuczne impulsy `addForce` ani `addTorque`.

Przy dużym obciążeniu efekt płynnie narasta do około:

- **tył:** `spring ×1.15`, `damping ×0.60` przy około `1.60×` obciążenia spoczynkowego osi,
- **przód:** `spring ×1.10`, `damping ×0.75` przy około `1.50×` obciążenia spoczynkowego osi.

Celem jest bardziej naturalna reakcja opon i zawieszenia pod dużym uciągiem, włącznie z możliwością krótkiego naturalnego power-hop, bez rozbujania pustego ciągnika.

## 1934 Widmo

Konfiguracja silnika `1934 Robert` została przemianowana na **1934 Widmo**. Techniczne nazwy części plików, m.in. kół Robert, pozostają bez zmian ze względu na zgodność ścieżek.

Widmo jest celowo mocniej zmodyfikowaną wersją ciągnika:

- moc sklepowa: **290 KM**,
- `torqueScale=1.100`,
- własny układ komponentów `3700 / 2500 kg`,
- COM `0 1.10 -1.80`,
- około **30.1% przód / 69.9% tył** na podstawowych kołach,
- tylne `forcePointRatio=0.80`,
- tylne `maxLongStiffness ×1.20`,
- tylne `maxLatStiffness ×0.85`,
- ręczne przełączanie RWD/4x4,
- możliwość pracy z fabryczną skrzynią 16/8 lub bezpośrednią 8/4 zgodnie z konfiguracją sklepu,
- dopłata za konfigurację Widmo: **+40000**.

Strojenie Widma ma zachować bardzo duży uciąg i naturalną możliwość odciążenia lub podniesienia przedniej osi pod ekstremalnym obciążeniem, a jednocześnie ograniczyć tendencję do przewracania się przez nadmierną przyczepność boczną.

## Kolory

Nadwozie i felgi mają niezależne konfiguracje kolorów:

- pełna natywna paleta GIANTS,
- własny kolor RGB,
- oddzielny wybór nadwozia i felg.

`UrsusColorFix.lua` przenosi wybrany kolor na zatwierdzoną whitelistę legacy materiałów I3D.

Kolor nadwozia obejmuje m.in. klapę dachową `SzyberDach/szyber`. Obciążniki kół, lampy, szyby, hydraulika, złącza, uszczelki i kalkomanie pozostają poza kolorowaniem.

## Advanced Damage System / Vehicle Years

Integracja jest opcjonalna — żaden z tych modów nie jest twardą zależnością Ursusa.

Przy aktywnym Advanced Damage System:

- automat respektuje awarie zmiany biegów i efekty opóźnienia powershift,
- logika skrzyni korzysta z dynamicznego obciążenia silnika,
- przy obciążeniu powyżej 80% ochronny automat może redukować bieg poniżej 65% maksymalnych obrotów,
- blokowane są przedwczesne zmiany w górę poniżej 83% maksymalnych obrotów,
- redukcje wykonywane są po jednym wirtualnym kroku z krótkim holdem po redukcji.

Dla Vehicle Years ciągnik ma ustawiony rok sklepowy `2009`.

Pojemność zbiornika paliwa: **355 l**.

## Znane problemy

`Ursus1934.i3d` może zgłaszać niekrytyczny warning:

`i3d contains non-binary indexed triangle sets`

Źródłem jest tekstowo zapisana geometria `FS25MirrorExact`. Warning nie powoduje zaobserwowanych problemów z działaniem ani wyglądem moda.

Konwersję tej geometrii do binarnego `.i3d.shapes` celowo odłożono, ponieważ wymagałaby ponownego testu zatwierdzonych lusterek.

## Walidacja i budowanie

Walidacja bieżącego stanu:

```bash
python3 tools/validate_current.py
```

Budowanie paczki:

```bash
./build.sh
```

`build.sh` automatycznie uruchamia walidator przed budowaniem. Gotowy mod trafia do:

`dist/FS25_Ursus_1654_1954_Pack.zip`

Builder korzysta z kontrolowanej allowlisty plików gry, dzięki czemu do ZIP-a nie trafiają `.git`, dokumentacja, narzędzia ani pliki robocze repozytorium.

Walidator sprawdza m.in.:

- poprawność XML/I3D,
- format wersji `A.B.C.D[K][N]`,
- ścieżki store itemów,
- wymagane skrypty z `extraSourceFiles`,
- obecność plików wymaganych przez builder,
- stałą nazwę wynikowego ZIP-a.

## Wersjonowanie

Numeracja historyczna `V1–V25` jest zamknięta.

Aktualne wydania używają formatu:

`A.B.C.D[K][N]`

Sufiksy testowe i serwisowe opisuje `VERSIONING.md` (`T`, `H`, `F`, `P`). Stabilne wydania nie mają sufiksu.

Zmiany pierwszego lub drugiego segmentu wersji mogą oznaczać świadomą zmianę kompatybilności zachowania. Przejście z 1.0.x do 1.1.1.0 jest właśnie takim przypadkiem ze względu na nową fizykę masy, konfiguracje skrzyni i napędu.

## Dokumentacja repozytorium

- `CHANGELOG.md` — pełna historia konwersji V1–V25, późniejszych stabilnych wydań i serii testowych,
- `PROJECT_STATE.md` — techniczne notatki robocze, parametry i historia zatwierdzanych konfiguracji,
- `VERSIONING.md` — zasady numerowania wydań i zachowania tożsamości moda,
- `reference/v25/` — historyczny punkt odniesienia V25; jego SHA manifest nie opisuje bieżącej wersji.

## Releases

Gotowe buildy są publikowane w GitHub Releases:

https://github.com/StrielokPL/Ursus16541954/releases

Stabilne wydania używają tagów w rodzaju `v1.1.1.0`, natomiast testy są publikowane jako GitHub Pre-release.

Asset moda zawsze zachowuje nazwę:

`FS25_Ursus_1654_1954_Pack.zip`

## Punkty bezpieczeństwa

Najważniejsze historyczne baseline'y:

- **V23 GEAR SAFE** — stabilna skrzynia 16F/8R i lokalny limiter automatu,
- **V24B HIGH/LOW SEQUENTIAL** — zatwierdzona sekwencja 8F/4R × L/H,
- **V25 COLLISION SAFE** — prawidłowe kolizje FS25,
- **1.0.3.0** — domknięcie cleanupu logu, tankowania, AI i świateł,
- **1.0.4.1** — stabilna integracja realizmu / ADS,
- **1.0.5.1** — stabilny system kolorowania,
- **1.1.1.0** — aktualny pełny baseline fizyki masy, napędu, skrzyni i dynamicznego zawieszenia.

## Zasady rozwoju

1. `main` jest bieżącą bazą projektu.
2. Zmiany wprowadzamy możliwie izolowanymi commitami i testujemy na pre-release'ach, jeżeli ingerują w fizykę lub zachowanie pojazdu.
3. Po akceptacji aktualizujemy wersję, changelog i publikujemy GitHub Release.
4. Nie wracamy do numeracji `V26`, `V27` itd.
5. Nie zmieniamy bez wyraźnej potrzeby zatwierdzonych obszarów, takich jak geometria lusterek, kolizje, zaczepy, WOM, tankowanie i istniejące ścieżki tożsamości moda.
