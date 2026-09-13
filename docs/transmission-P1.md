# Automat 1.1.1.1 P1 i plan stabilizacji osi Widma

## Materiał odniesienia

Bazowy sterownik: 1.1.1.0, commit `7c321c65df98b9c774e649d0d20973f1deaee82b`. Test użytkownika: log z 2026-09-13, FS25 1.23.1.0, sonda D2. Przebieg: Widmo 290 KM na pusto, transport z Titan 18, orka na kołach podstawowych, drugi wariant z bliźniakami i zmienionym balastem. Sonda rozróżnia obiekty motoru v1/v2, nie trwałe identyfikatory pojazdów. D2 nie zapisała numeru konfiguracji kół ani bieżącego przełączenia napędu Widma; przypisanie etapów do kół pochodzi z opisu testera.

- 20:15:54–20:16:02: wymuszony ciąg 1L, 1H, 2L, 2H…8L.
- 20:17:30–20:18:45: mediana 32.064 km/h, 2200.962 obr./min, ADS 0.320, pełny gaz i brak limitu narzędzia. Sterownik nie podejmował poprawnego transportowego 8L→8H.
- 20:19:03.853–04.372: 1H→2L, 2.331→0.257 km/h. Gaz wejściowy 1, hamulec 0, podczas rozłączenia gaz wynikowy 0; około 353 ms między zdarzeniami rozłączenia i załączenia.
- 20:19:12.237–13.029: 3H→4L, 5.509→1.286 km/h.
- 20:16:57.855: wynik predykcji 7 przy aktualnym 8, ale grupa zmieniona L→H zanim zaakceptowano redukcję. Dwie próbki stanu pokazują 8H przy 11–12 km/h i około 925–945 obr./min.
- Ustalona orka: pierwszy odcinek 20:19:22–33, drugi 20:20:58–21:09. Mediany prędkości 10.633 i 11.098 km/h, oba 5H; ADS 1.015 i 1.010, GIANTS 0.974 i 0.966. Masa zestawu 13.286 i 15.373 t. Wskaźnik poślizgu tyłu 0.056 i 0.003. Różnicy nie wolno przypisywać tylko kołom: zmieniły się również masa i warunki przejazdu.

Brak błędów Lua i ostrzeżeń sondy o utracie zdarzeń. Brak raportowanych aktywnych efektów opóźnienia PS/nieudanej zmiany ADS. Nie oznacza to braku wpływu ADS na obciążenie silnika.

## Zastosowana metoda

Przeniesiono z doświadczeń C330 sprawdzanie zapasu po zmianie, czas stabilizacji, pamięć nieudanego przełożenia, awaryjną redukcję i zachowanie pełnych zwrotów opakowanych metod. Nie przeniesiono tabel biegów/range C330: Ursus ma 8F/4R i półbiegi, więc obliczenia korzystają z rzeczywistych `gears[].ratio` i `gearGroups[].ratio` w uruchomionym motorze.

Efektywne przełożenie `R = abs(gear.ratio * group.ratio)`.
Dla proponowanej zmiany `f = R_docelowe / R_obecne`:

- przewidywane obroty: `rpm_docelowe = rpm_obecne * f`;
- szacowane obciążenie: `load / f`, z korektą ilorazem momentów krzywej silnika w obecnym i docelowym punkcie, jeżeli odczyty są dostępne;
- obroty przy limicie narzędzia: `limit_kmh / 3.6 * R_docelowe * 30 / pi`.

To heurystyka wyboru, a nie pełna symulacja siły uciągu. Nie przewiduje idealnie strat przy rozłączeniu, zmian poślizgu, nachylenia i gruntu. Przy braku odczytu krzywej momentu pozostaje ostrożniejsze oszacowanie samym ilorazem przełożeń.

## Progi P1 — kalibracja do testu

| Warunek | P1 |
|---|---|
| Źródło obciążenia | skończony odczyt ADS, awaryjnie GIANTS; wartości ujemne do decyzji ograniczone do 0 |
| Filtrowanie obciążenia | stała 400 ms; bez aktualizowania filtra spadkiem obciążenia na rozłączonej skrzyni |
| Lekki transport | brak aktywnego limitu narzędzia i obciążenie <0.70 |
| Start do przodu | bez limitu narzędzia: 2H do 12 t, 1H powyżej; praca/brak danych: 1L |
| Start wstecz | 1L |
| Minimalne obroty do awansu | 1900 transport, 2000 pozostałe |
| Minimalne obroty po awansie | 1250 transport, 1500 pozostałe |
| Maksymalny szacowany load po awansie | 0.92 |
| Limit narzędzia | awans nie może przewidywać <1500 obr./min przy tym limicie |
| Poślizg tylnych kół | >0.22 blokuje awans; brak pola nie jest dowodem zerowego poślizgu |
| Prędkość rzeczywista | przynajmniej 72% wynikającej z biegu i aktualnych obrotów |
| Trend prędkości | spadek szybszy niż 0.30 km/h na sekundę blokuje awans |
| Stabilna gotowość | 350 ms transport, 700 ms praca |
| Po załączeniu | 600 ms lokalnej przerwy; awans dodatkowo wymaga stabilnego stanu |
| Redukcja | load >0.78 i rpm <1450, albo rpm <1100 przy ruchu >1.1 km/h; warunek przez 250 ms |
| Ochrona przed nadobrotami redukcji | prognoza nie wyższa niż maxRpm+50 |
| Po redukcji | awans wstrzymany 1800 ms |
| Nieudany wyższy bieg | redukcja w ciągu 8 s od własnego awansu; powtórka nie wcześniej niż 5 s i po poprawie rezerwy |

Na drodze z małym obciążeniem następny kandydat to kolejny H. Jeśli nie ma na niego rezerwy, automat czeka, zamiast obowiązkowo dokładać L. Z L może wejść na H bez czekania na propozycję dziewiątego biegu. Przy obciążeniu rozważa najbliższy wyższy krok L/H. Pamięć nieudanej próby wymaga spadku obciążenia o 0.12 względem próby lub odzyskania wystarczającej rezerwy drogowej (demand ≤0.75, przewidywane rpm ≥1400).

## Załączenie i granice odpowiedzialności

Dla zmiany głównej predykcja zapisuje plan, ale nie przestawia grupy. Plan odpada, jeśli oryginalna aktualizacja nie zaakceptuje docelowego biegu lub zmieni kierunek. Grupa jest przestawiana dopiero w wywołaniu załączenia docelowego biegu. Zagnieżdżone wywołanie załączenia przez setter PS zostaje w tym jednym miejscu pominięte; oryginalne załączenie wykonuje się raz. Nie ma skracania timera mechanicznej zmiany ani dopisywania gazu na rozłączonej skrzyni.

Dotychczasowy adapter ADS dopuszcza/opóźnia/odrzuca zmianę półbiegu. Zmiany główne nadal wykonują oryginalne metody i ich zainstalowane opakowania. Awaryjna redukcja zwalnia wyłącznie kierunkowe weto GIANTS; nie usuwa mechanicznego czasu zmiany. Zwykły hamulec, tryb ręczny, opcja bez PS i inne pojazdy zachowują oryginalne wywołania. Wszystkie wyniki `updateGear`, w tym hamulec i ewentualne dodatkowe/nil, są przekazywane dalej.

Sprawdzone na oficjalnym [VehicleMotor, FS25 Script 1.20](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=91&class=896&version=script): kolejność predykcji, weta i załączenia oraz zachowanie settera PS. Gra testera to 1.23.1.0; izolowany harness odwzorowuje istotną kolejność, nie cały silnik gry.

## Wahliwość przedniej osi — osobny etap strojenia

Aktualny zawias `vehicle.base.components.joint`: komponenty 1↔2, węzeł `1>0`, oś lokalna Z, limit `0 0 14`, sprężyna ogranicznika `0 0 4000`, tłumienie ogranicznika `0 0 0`. Napęd obrotu ma zerowe maxRotDriveForce, rotDriveSpring i rotDriveDamping; rotDriveRotation jest ustawione na 0.

**Możliwość techniczna istnieje.** GIANTS tworzy napęd kątowy zawiasu z pól rotDriveRotation/Velocity, Spring, Damping i maxRotDriveForce. Zobacz [Vehicle: loadComponentJoint/createComponentJoint](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=91&class=888&version=script). Tłumienie ogranicznika dotyczy końca zakresu; aby stawiać opór podczas ruchu w zakresie, trzeba stroić napęd kątowy i jego limit siły.

Proponowana kolejność następnych prób wyłącznie Widma:

1. Zarejestrować kąt i prędkość względną belki, przechył kadłuba, kontakt/naciski kół oraz konfigurację napędu i balastu. Stan D2 nie pozwala oddzielić przechyłu zawiasu od kadłuba.
2. Porównać umiarkowane zmniejszenie zakresu ±14° do ±10°. To próba kalibracyjna, nie docelowa wartość fabryczna.
3. Dodać tłumienie ruchu z ograniczoną siłą napędu kątowego. Dopiero potem niewielką sprężynę centrującą do 0°. Nie wyznaczać parametrów siły/sprężyny na ślepo z samej masy pojazdu.
4. Testować identyczny slalom przy stałej prędkości, nierówność pod jednym kołem, nawrót z podniesionym pługiem oraz ruszanie z odrywaniem przodu. Oddzielnie mały i duży balast, 4x4/RWD.
5. Docelowo osobny profil/konfiguracja lub ograniczona do Widma modyfikacja deskryptora zawiasu przed utworzeniem fizyki. Nie zmieniać wspólnego XML dla wszystkich silników, jeśli celem jest tylko Widmo. Sprawdzić odbudowę po warsztacie i serwer MP.

Opór osi może ograniczyć szybkie wychylenie kadłuba względem przedniej belki, ale nie usuwa ryzyka przewrócenia całego ciągnika przy wysokim COM. Przy przodzie w powietrzu oś nie ma kontaktu z gruntem i nie zapewni zwykłego podparcia bocznego. Zbyt sztywny zawias pogorszy dopasowanie kół do terenu. Nie należy kompensować tego sztucznym momentem stabilizującym cały pojazd ani niejawnie zmieniać COM.

## Co pozostaje do sprawdzenia

- Czy 2H jest odpowiednim lekkim startem także dla słabszych silników, a 1L pod Titanem nie trzyma zbyt długo z powodu poślizgu.
- Czy progi 0.70/0.92 pozwalają na sensowne pomijanie L przy transporcie, zachowując rezerwę na podjeździe.
- Spadki prędkości przy przejściu między biegami głównymi: P1 usuwa błędy wyboru/koordynacji, ale zostawia rzeczywiste rozłączenie 350 ms.
- Zużyty ADS w logu drugiego użytkownika, więcej konfiguracji silników, cofanie i MP.
- Strojenie zawiasu przedniej osi jako osobny test po ocenie skrzyni.
