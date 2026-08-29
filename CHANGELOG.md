# Changelog konwersji FS22 → FS25

## Punkty bezpieczeństwa
- **V23 GEAR SAFE** — stabilna skrzynia 16F/8R + lokalny limiter automatu.
- **V24B HIGH/LOW SEQUENTIAL** — działająca skrzynia 8F/4R × L/H.
- **V25 COLLISION SAFE** — prawidłowe kolizje FS25; historyczny ostatni baseline numeracji Vxx.
- **1.0.1.0** — pierwszy stabilny baseline nowej czteroczłonowej numeracji.
- **1.0.2.2** — stabilna regulacja górnego tylnego zaczepu względem WOM-u.

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

## 1.0.2.0
Stabilne wydanie zatwierdzonego cyklu CLEANUP TEST 1–24.

Najważniejsze zmiany względem 1.0.1.0:
- usunięto nieistniejące mapy materiałów złączy oraz legacy wpisy dźwięków powodujące błędy podczas ładowania,
- poprawiono `schemaOverlay` i usunięto nieaktualny dźwięk `ATTACH_01` z `Weight2500kg.xml`,
- główny component otrzymał bit `FILLABLE`, dzięki czemu trigger stacji prawidłowo wykrywa paliwo; tankowanie potwierdzono w grze,
- konfiguracja przedniego TUZ-a tworzy przedni joint tylko dla TUZ-a, a WOM i przewody korzystają z właściwych punktów z przodu,
- usunięto globalne legacy jointy pozwalające podpinać sprzęt mimo braku TUZ-a,
- skorygowano obrys głównej kolizji maski,
- rozdzielono kolizje przedniego wyposażenia na: szeroką rodzinę pierwszego FrameWeight/1200/2000 kg, wąską rodzinę drugiego FrameWeight/600/1500 kg, osobny TUZ oraz brak dodatkowej kolizji dla pustej konfiguracji,
- finalne boxy rodzin obciążników obniżono o 5 cm; szeroką rodzinę rozsunięto dodatkowo po 10 cm na stronę,
- zachowano działającą skrzynię, silniki, lusterka, koła, hydraulikę, animacje, światła i pozycję kierowcy z wcześniejszych zatwierdzonych baz.

Testy runtime potwierdziły tankowanie, ogólne kolizje, poprawne przełączanie wariantów przedniego wyposażenia i finalne pozycje boxów.

## 1.0.2.2
Stabilne wydanie regulacji tylnego zaczepu.

Zmiany względem 1.0.2.0:
- górny zaczep na pin `trailer` zachowuje maksymalną wysokość `Y 1.040`, a jego dolny limit ustawiono na `Y 0.760`,
- dolny, nieruchomy zaczep kulowy `trailerLow` pozostał bez zmian,
- tylne wyjście WOM nadal obsługuje indeksy zaczepów `1 2 3`, a przednie wyjście indeks `4`,
- nie zmieniono kolizji, przednich obciążników, TUZ-a, tankowania ani tożsamości paczki,
- walidator i `VERSIONING.md` obsługują uzgodniony format `A.B.C.D[K][N]` oraz sufiksy `H/F/T/P`.

Pośrednia wersja `1.0.2.1T1` służyła do sprawdzenia rozszerzonego zakresu górnego zaczepu. W wydaniu stabilnym dolny limit obniżono o kolejne 2 cm.


## 1.0.3.0
Stabilne wydanie domykające czyszczenie logu po 1.0.2.2.

Zmiany względem 1.0.2.2:
- dodano `<ai><agentAttachment useSize="true"/></ai>` do obciążnika 2500 kg, dzięki czemu gra otrzymuje prawidłowy obrys AI i nie zgłasza brakującej definicji,
- dodano osobny niewidoczny box FILLABLE `exactFillRootNodeFuel` w centralnej części ciągnika i przypisano go wyłącznie do paliwowego `fillUnit`; tankowanie nadal działa jak wcześniej,
- usunięto jeden odrzucany `defaultLight` wskazujący zwykłą warstwę kokpitu oraz pięć odrzucanych wpisów `EMITTER` zegarów,
- geometria świateł, lokalny shader, tekstura emisyjna, jasność, kolor i zachowanie właściwych lamp pozostały bez zmian,
- zachowano stałą nazwę paczki i ścieżki XML, więc aktualizacja nie zmienia tożsamości moda ani zakupionych maszyn.

Testy runtime:
- potwierdzono działanie tankowania,
- potwierdzono poprawne zachowanie obciążnika 2500 kg dla AI,
- potwierdzono brak zmian w wyglądzie i działaniu świateł oraz zegarów,
- usunięto łącznie osiem wcześniejszych warningów: jeden obciążnika AI, jeden `exactFillRootNode`, jeden `staticLight` i pięć `dashboard EMITTER`,
- log nie zawiera błędów związanych z Ursusem.

### Znane problemy
- `Ursus1934.i3d` nadal zgłasza nieszkodliwy warning `i3d contains non-binary indexed triangle sets`. Źródłem jest tekstowo zapisana geometria `FS25MirrorExact`.
- Warning nie powoduje zaobserwowanych problemów z działaniem ani wyglądem moda. Konwersję tej geometrii do binarnego `.i3d.shapes` odłożono, ponieważ wymaga zmiany assetu modelu i ponownego testu zatwierdzonych lusterek.
- Warningi generowane przez grę, zapis lub inne mody nie należą do tego wydania.








## 1.0.6.0T3
Test napędu RWD dla konfiguracji `1934 Widmo`.

Zmiany względem 1.0.6.0T2:
- Widmo zachowuje silnik 1934 Chip 225 KM i środek masy `0 1.05 -1.65`,
- tylko dla `1934 Widmo` skrypt przechwytuje `Motorized.loadDifferentials()` i przed `addToPhysics()` pozostawia wyłącznie tylny dyferencjał,
- przednia oś Widma jest w T3 swobodnie tocząca, bez doprowadzanego momentu; pozostałe warianty silnika nadal korzystają z seryjnego 4x4,
- celem T3 jest sprawdzenie, czy centralny rozdział 50/50 ogranicza moment dostępny na tylnej osi po odciążeniu lub uślizgu przodu,
- nadal brak sztucznego `addTorque`/`addForce`; test pozostaje oparty na fizyce GIANTS.

## 1.0.6.0T2
Drugi test fizycznej skłonności Widma do podnoszenia przedniej osi.

Zmiany względem 1.0.6.0T1:
- `1934 Widmo` otrzymuje pełną charakterystykę silnika `1934 Chip`: 225 KM, `torqueScale=0.850` i tę samą krzywą momentu,
- środek masy Widma cofnięto o kolejne 40 cm: z `0 1.05 -1.25` do `0 1.05 -1.65`,
- wysokość środka masy pozostaje bez zmian względem T1,
- nadal brak `addTorque`, `addForce` i innych skryptowych impulsów; T2 nadal testuje wyłącznie naturalną fizykę gry,
- pozostałe warianty silnika i fizyka stabilnego 1.0.5.1 pozostają bez zmian.

## 1.0.6.0T1
Test fizycznej skłonności wersji Widmo do podnoszenia przedniej osi pod bardzo dużym obciążeniem.

Zmiany względem stabilnego 1.0.5.1:
- konfigurację silnika `1934 Robert` przemianowano na `1934 Widmo`,
- tylko Widmo otrzymuje zmieniony środek masy głównego komponentu: `0 1.05 -1.25` zamiast bazowego `0 0.8 -0.88`,
- środek masy jest około 25 cm wyżej i 37 cm bardziej z tyłu; celem jest umożliwienie naturalnego odciążenia lub uniesienia przodu przy dużym uciągu,
- brak sztucznego `addTorque`, `addForce` i innych skryptowych impulsów; T1 testuje wyłącznie fizykę silnika gry,
- techniczne nazwy plików kół Robert pozostają bez zmian,
- pozostałe konfiguracje silnika, skrzynia, ADS, kolory, koła, kolizje i hydraulika pozostają bez zmian.

## 1.0.5.1
Stabilne wydanie systemu kolorowania testowanego w serii 1.0.5.0T1–T5.

Zmiany względem 1.0.4.1:
- nadwozie i felgi otrzymały niezależne konfiguracje kolorów,
- `baseColor` i `rimColor` korzystają z pełnej natywnej palety GIANTS (`useDefaultColors=true`) oraz pickera koloru niestandardowego RGB,
- `UrsusColorFix.lua` przenosi rzeczywisty kolor wybranej konfiguracji na zatwierdzoną whitelistę legacy meshów nadwozia i felg,
- sygnatura konfiguracji uwzględnia RGB, dzięki czemu wykrywana jest również zmiana koloru niestandardowego przy tym samym indeksie konfiguracji,
- obciążniki kół, lampy, szyby, hydraulika, złącza i kalkomanie pozostają poza kolorowaniem,
- naprawiono pakowanie `UrsusColorFix.lua`; walidator sprawdza teraz wszystkie `extraSourceFiles` wymagane przez `modDesc.xml`,
- dodano klapę dachową `SzyberDach/szyber` do elementów malowanych kolorem nadwozia, bez zmiany jej animacji, ramy, uszczelek ani mechanizmu,
- skrzynia, ADS, silniki, fizyka, koła, kolizje i pozostałe wcześniej zatwierdzone funkcje nie zostały zmienione.

Test runtime T5 potwierdził poprawne kolorowanie klapy dachowej. Log `20260829-110303` nie zawiera nowych błędów Lua ani błędów związanych z Ursusem. Pozostaje wyłącznie zaakceptowany warning `Ursus1934.i3d contains non-binary indexed triangle sets` związany z geometrią `FS25MirrorExact`.

## 1.0.5.0T5
Poprawka koloru klapy dachowej.

Zmiany względem 1.0.5.0T4:
- dodano mesh `szyber` z grupy `SzyberDach` do listy elementów malowanych kolorem nadwozia,
- klapa dachowa korzysta z materiału z `colorMat0` i typem materiału 16, więc otrzymuje ten sam wybrany kolor co karoseria,
- ramy, uszczelki, mechanizm klapy, koła, skrzynia, ADS i pozostałe elementy nie zostały zmienione.

## 1.0.5.0T4
Hotfix pakowania po 1.0.5.0T3.

Zmiany względem 1.0.5.0T3:
- naprawiono paczkę ZIP: `UrsusColorFix.lua` jest teraz jawnie dołączany do listy plików moda,
- brak skryptu w ZIP-ie był bezpośrednią przyczyną błędu `Can't load resource .../UrsusColorFix.lua` i braku faktycznej zmiany kolorów w T3,
- mechanizm pełnej palety GIANTS i koloru niestandardowego pozostaje bez zmian względem T3, aby T4 izolował wyłącznie błąd pakowania,
- walidator sprawdza teraz, czy każdy plik z `modDesc.xml/extraSourceFiles` istnieje i znajduje się na allowliście buildera; podobna regresja ma od tej wersji przerwać build.

## 1.0.5.0T3
Test pełnej palety kolorów i koloru niestandardowego.

Zmiany względem 1.0.5.0T2:
- potwierdzony w grze bridge kolorowania nadwozia/felg pozostaje bazą,
- `baseColor` i `rimColor` używają `useDefaultColors=true`: pełna natywna paleta GIANTS i picker koloru niestandardowego,
- usunięto diagnostyczny wściekły róż/magentę z ręcznie zdefiniowanej palety,
- bridge pobiera rzeczywisty RGB z `VehicleConfigurationItemColor`, również z `vehicle.configurationData` dla koloru niestandardowego,
- sygnatura uwzględnia RGB, więc zmiana własnego koloru przy tym samym indeksie jest wykrywana,
- usunięto diagnostyczne logowanie liczby przemalowanych elementów z T2,
- F5 jest globalnym debug-rendererem GIANTS pokazującym prawdziwe kolizje; nie wyłączano go kosztem kolizji.

## 1.0.4.0T1
Testowa iteracja kompatybilności z modami realizmu.

Zmiany względem 1.0.3.0:
- dodano rok produkcji `2009` do danych sklepowych pojazdu dla zgodności z Vehicle Years i systemami korzystającymi z `storeData.year`,
- pojemność zbiornika oleju napędowego zwiększono z `300 l` do historycznie właściwych `355 l`,
- `UrsusTransmissionFix.lua` otrzymał opcjonalny bridge do Advanced Damage System: automatyczny splitter L/H respektuje `GEAR_SHIFT_FAILURE_CHANCE` oraz opóźnienie uszkodzonego powershiftu; bez ADS zachowanie pozostaje bez zmian.

## 1.0.4.0T2
Test doboru przełożeń automatu zależnego od obciążenia silnika z ADS.

Zmiany względem 1.0.4.0T1:
- automat przy aktywnym ADS odczytuje ten sam `spec.dynamicMotorLoad`, którego ADS używa do telemetrii i zużycia silnika,
- przy stanie lugging zgodnym z ADS (`dynamicMotorLoad > 80%`, obroty `< 60% max RPM`, pojazd w ruchu) wymuszany jest jeden krok w dół w sekwencji L/H,
- przy obciążeniu >80% blokowany jest upshift, jeśli silnik pracuje poniżej 75% maksymalnych obrotów; chroni to przed spadkiem obrotów po zmianie L→H do strefy lugging,
- po ochronnym downshifcie działa krótka histereza 1,8 s, aby automat nie cofał natychmiast decyzji,
- log zapisuje tylko faktyczne ingerencje load guarda (`DOWNSHIFT` / `BLOCK UPSHIFT`) wraz z biegiem, obciążeniem i RPM,
- bez ADS oraz w trybie manualnym zachowanie pozostaje takie jak w T1.


## 1.0.4.0T3
Hotfix testowy mechanizmu ADS load guard.

Zmiany względem 1.0.4.0T2:
- naprawiono błąd diagnostyki `Logging.info`, który pojawiał się dokładnie przy pierwszej ingerencji load guarda (`missing argument #2`),
- przyczyną był znak `%` w już sformatowanym komunikacie przekazywanym ponownie do formattera GIANTS Logging,
- błąd przerywał metodę `update` przed zakończeniem decyzji skrzyni, przez co ochronna redukcja lub blokada upshiftu nie mogła działać prawidłowo,
- progi ADS, sekwencja biegów i czasy histerezy pozostają bez zmian względem T2, aby T3 izolował wyłącznie ten błąd.


## 1.0.4.0T4
Testowe zwiększenie marginesu ochronnego ADS load guard.

Zmiany względem 1.0.4.0T3:
- próg ochronnej redukcji przy obciążeniu >80% podniesiono z 60% do 65% maksymalnych obrotów (~1320 → ~1430 rpm dla 2200 rpm),
- próg blokady upshiftu pod wysokim obciążeniem podniesiono z 75% do 83% maksymalnych obrotów (~1650 → ~1825 rpm),
- zmiana zostawia bezpieczny zapas obrotów po przejściu L→H (1.25 → 1.00) zamiast lądowania dokładnie na granicy luggingu ADS,
- próg obciążenia, czasy cooldown/histerezy, redukcja o jeden wirtualny stopień i bridge awarii ADS pozostają bez zmian.

## 1.0.4.1
Stabilne wydanie zmian testowanych w serii 1.0.4.0T1–T4, ukierunkowanych na zgodność z modami realizmu i zachowanie automatycznej skrzyni pod dużym obciążeniem.

Zmiany względem 1.0.3.0:
- dodano rok produkcji `2009` do danych sklepowych dla zgodności z Vehicle Years i systemami korzystającymi z `storeData.year`,
- pojemność zbiornika oleju napędowego zwiększono z `300 l` do `355 l`, zgodnie z danymi ciężkiej serii Ursusa,
- dodano opcjonalny bridge do Advanced Damage System dla automatycznego splittera L/H; zmiany splittera respektują awarie zmiany biegu ADS oraz opóźnienie/uszkodzenie powershiftu,
- automat z aktywnym ADS korzysta z `spec.dynamicMotorLoad`, czyli tego samego sygnału obciążenia, którego ADS używa do telemetrii i zużycia silnika,
- przy obciążeniu >80% ochronna redukcja uruchamia się poniżej 65% maksymalnych obrotów (~1430 rpm przy 2200 rpm),
- przy obciążeniu >80% blokowany jest upshift poniżej 83% maksymalnych obrotów (~1825 rpm), aby po przejściu L→H zachować zapas ponad strefą luggingu,
- ochronna redukcja pozostaje ograniczona do jednego wirtualnego stopnia naraz, z cooldownem oraz histerezą 1,8 s zapobiegającą polowaniu między przełożeniami,
- naprawiono diagnostykę load guarda, tak aby wpisy `DOWNSHIFT` / `BLOCK UPSHIFT` nie powodowały błędu formattera GIANTS Logging,
- bez ADS oraz w trybie manualnym zachowanie skrzyni pozostaje zgodne ze stabilnym mechanizmem 8F/4R × L/H.

Testy runtime:
- seria T4 przeszła test normalnej pracy oraz test graniczny z pługiem wymagającym 210 KM, w deszczu i przy 100% wilgotności gleby,
- load guard poprawnie blokował zbyt wczesne upshifty i wykonywał ochronne redukcje bez błędów Lua,
- brak nowych błędów związanych z Ursusem.

### Znane problemy
- pozostaje zaakceptowany warning `Ursus1934.i3d contains non-binary indexed triangle sets` związany z tekstową geometrią `FS25MirrorExact`; nie ma zaobserwowanego wpływu na działanie ani wygląd.


## 1.0.5.0T1
Pierwszy test niezależnej zmiany koloru nadwozia i felg.

Zmiany względem 1.0.4.1:
- dodano natywną konfigurację `baseColorConfigurations` dla głównego materiału nadwozia (`Object118` + `kadlubmetal`),
- dodano niezależną `rimColorConfigurations` dla właściwych materiałów obręczy w `wheels/rims.i3d`,
- obciążniki kół, lampy, złącza, hydraulika, szyby i kalkomanie nie są objęte konfiguracją koloru,
- T1 używa małej palety kontrolnej i zerowych cen; celem jest wyłącznie test zakresu malowanych powierzchni,
- konfiguracje silnika, skrzyni, ADS, kół i fizyki pozostają bez zmian względem 1.0.4.1.

Uwaga testowa:
- oba warianty materiału obręczy (standard oraz Robert) używają wspólnego slotu koloru, dlatego domyślny szary może ujednolicić dotychczasowy czerwony wariant felg Robert. To jest świadome w T1 i zostanie ocenione po teście wizualnym.

## Dalszy rozwój
Od **1.0.1.0** używamy wyłącznie czteroczłonowej numeracji opisanej w `VERSIONING.md`. Numeracji V26/V27 nie stosujemy do nowych buildów.
