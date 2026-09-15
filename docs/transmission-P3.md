# P3 — przeciążenie i ocena prób półbiegu

## Podstawa: log P2 z 14.09.2026
Odczytano pięć części, łącznie 43 614 341 bajtów. P2 i D3 potwierdzone w nagłówkach, bez błędów Lua. Identyfikatory v1/v2/v3 to kolejne obiekty silnika, nie trwałe identyfikatory pojazdów; po zmianie konfiguracji starsze obiekty nadal były próbkowane. Analiza aktywnego obiektu wyklucza stare próbki.

Mediany stabilniejszych odcinków:
| Czas | Koła | Bieg | rpm | km/h | ADS |
|---|---|---|---:|---:|---:|
|18:51:43–18:52:17|zwykłe|5H|1899|8,60|1,060|
|18:55:10–18:55:25|zwykłe|5L|2205|9,47|1,034|
|18:57:50–18:57:57|bliźniaki|5L|2214|10,20|0,914|
|18:58:50–18:59:30|bliźniaki|5L|2195|10,52|0,937|

Druga orka ma zakłócenie: tester zmienił ciśnienie pługa zamiast ciągnika. Nie jest to kontrolowany pomiar wpływu ciśnień. ADS jest wskaźnikiem obciążenia, nie pomiarem KM. Dwie późniejsze próby 5H cofnięto po około 0,6 s; pierwszy przejazd trzymał 5H z ADS>1,0 przez 117/130 próbek wybranego odcinka. Nie dowodzi to, że każda praca na 5H jest błędna.

## Reguły P3
POWER_PROBE zachowuje pozostałe warunki P2, lecz ogranicza load do 0,90 i prognozę do 0,98. Normalny limit rezerwy pozostaje 0,92. To kalibracja testowa, nie pomiar fabryczny.

SUSTAINED_OVERLOAD: wyłącznie ADS, aktywny limit narzędzia, jazda do przodu, gaz i brak hamowania, oba tylne kontakty, znany poślizg tylny <=0,22, prędkość >1,2 km/h. Po minimum 1000 ms ustalenia przełożenia wymagane kolejne 2500 ms: surowy load >0,98 i filtr 400 ms >1,02. Luka próbkowania >150 ms resetuje ciągłość. Zmiana przełożenia, brak danych i przerwanie warunków resetują licznik. Normalna redukcja przy duszeniu silnika pozostaje niezależna.

Redukcja dotyczy najbliższego niższego przełożenia; obliczone obroty nie mogą przekroczyć maxRpm+50. Przy 5H/1900 rpm prognoza 5L wynosi 2375: redukcja czeka, POLICY=OVERLOAD_RPM_GUARD. Zaostrzenie dopuszczenia H ogranicza wejście w ten stan, ale nie gwarantuje jego wyeliminowania przy zmianie warunków już podczas jazdy. Nie zmieniamy gazu ani fizyki, by wymusić zmianę.

Potwierdzona redukcja tworzy pamięć nieudanego przełożenia także po upływie 8 s. Z własną próbą zachowuje obciążenie sprzed niej; bez takiej próby szacuje je proporcją przełożeń. Ponowienie wymaga przynajmniej 5 s i poprawy o 0,12 według istniejącego mechanizmu (z dotychczasowym wyjątkiem rezerwy drogowej).

## Diagnostyka zgodna z D3
Sterownik publikuje URSUSPSTRIAL tylko gdy g_modIsLoaded.FS25_ZZ_Ursus1654Diagnostic jest aktywne. Brak twardej zależności, brak podmiany sondy. Id próby jest unikalne w sesji sterownika. BEGIN zawiera przełożenia oraz dane sprzed zmiany. REDUCED oznacza decyzję powrotu; INTERRUPTED zmianę kontekstu/sterowania; OBSERVED/HELD_5S wyłącznie utrzymanie przez pięć sekund, nie sukces ekonomiczny ani dowód optymalności.

Średnie load i prędkości oraz minimum rpm liczone są po 600 ms od zmiany; średnie są próbkowe, nie ważone czasem. Zapis ograniczony do początku i zakończenia, bez spamu co klatkę. Istniejący POLICY D3 pokazuje SUSTAINED_OVERLOAD/OVERLOAD_RPM_GUARD, o ile trafi w klatkę decyzji. Brak kąta belki i rzeczywistego ciągłego ciśnienia nadal ogranicza interpretację przejazdów po deskach.

## Walidacja
74 asercje: dotychczasowe ścieżki drogowe, PS, ADS i synchronizacja oraz nowe przeciążenie, czas utrzymywania, ochrona rpm, wykluczenia drogi/poślizgu/braku kontaktu/hamowania/braku ADS, pamięć ponowienia i ograniczona diagnostyka. Harness nie emuluje opony/gleby ani zmian rpm w fizyce gry.
