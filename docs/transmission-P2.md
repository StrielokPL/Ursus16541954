# Strojenie P2 na podstawie logu P1 / D3

## Dowody
Test z 13.09.2026: na drodze potwierdzono kolejne H oraz około 40 km/h na 8H. Orka na zwykłych oponach, 21:10:39–53: 53 próbki, wszystkie SLIP_OR_SPEED_FALLING, 1L, mediana 1,87 km/h, 2195 rpm, load około 0,42, wskaźnik poślizgu tyłu około 0,47. Zabezpieczenie P1 >0,22 uniemożliwiało wyjście mimo rezerwy silnika. Dalsze GROUND_SPEED/STABILIZING wskazały przerywanie gotowości na nierównościach. Na bliźniakach 5L przy około 10,33 km/h, prognozy przejścia na 5H około 0,97–1,05 były powyżej stałego limitu 0,92.

Przy zmianach ciśnienia pojawiały się żądania luzu; tester podejrzewa wspólny Ctrl. Konflikt niepotwierdzony, nie jest źródłem blokady 1L w powyższym odcinku. Ciśnienie zapisano jako docelowe, nie jako ciągły pomiar rzeczywistego ciśnienia. D3 nie mierzy kąta przedniej belki, więc nie dowodzi poprawy jej stabilizacji.

## P2 — nowe reguły kalibracyjne
1. TRACTION_STEP: tylko aktywny limit pracy, oba tylne koła raportują kontakt, poślizg >0,22 i ≤0,65, obciążenie <0,65, rpm ≥2050, prędkość ≥1,2 km/h i ≥45% teoretycznej, trend ≥−0,15 km/h/s. Najbliższy krok wirtualnej skrzyni, prognozowany load ≤0,80, zwykła ochrona obrotów i limitu narzędzia. Gotowość 1200 ms. Brak danych kontaktu nie pozwala zastosować wyjątku. Nie jest to układ kontroli trakcji ani gwarancja poprawy uciągu.
2. Dla pozostałej lekkiej pracy (load <0,75) próg prędkości względem teoretycznej zmniejszono z 72% do 60%. Przy większym obciążeniu i na drodze pozostaje 72%.
3. Gotowość jest sumą czasu spełnionych warunków dla tego samego przełożenia. Przy zmianie rodzaju dopuszczenia obowiązuje najdłuższy wymagany czas z bieżącej próby. Krótkie odchylenie maks. 200 ms pauzuje licznik; nie nalicza czasu niedopuszczalnego. Dłuższa przerwa resetuje gotowość. Zmiana kandydata, hamowanie, kierunek, brak danych i faza odzyskiwania po zmianie nadal resetują właściwy stan.
4. POWER_PROBE: tylko L→H w tym samym biegu głównym, aktywna praca, oba kontakty tylne, slip ≤0,18, rpm ≥2100, prognozowane rpm ≥1650, load ≤0,97, prognozowany load ≤1,05, trend ≥−0,10 km/h/s. Powyżej normalnego limitu 0,92 wymagane 1500 ms gotowości. Zmiana główna nadal ma limit 0,92. Pamięć poprzedniej nieudanej próby i ADS pozostają obowiązujące.
5. Przez 5 s po własnej POWER_PROBE: load >0,90 i rpm <1550 może uruchomić redukcję po 250 ms utrzymywania się warunku, z zachowaniem czasu stabilizacji po zmianie i ochrony przed nadobrotami. Redukcja zapisuje nieudaną próbę; ponowienie wymaga 5 s oraz poprawy rezerwy według reguł P1.

Wartości są nastawami testowymi. W szczególności próg prognozy 1,05 nie oznacza zezwolenia na dowolnie długie przeciążenie ani podniesienia mocy silnika. D3 pokaże powody TRACTION_STEP, POWER_PROBE, SLIP_BLOCK, SPEED_FALLING, GROUND_SPEED oraz standardowe stany. Wewnętrzne nowe liczniki nie są osobno logowane w D3.

## Regresje
Zachowane testy P1: 8H, H na drodze, tryb ręczny, brak PS, klient, zwroty gaz/hamulec/nil, czas mechanicznej zmiany, pojedyncze załączenie i veto, ADS, redukcja i pamięć nieudanej próby. Dodane reprodukcje utknięcia 1L, długi poślizg bez kontaktu/brak kontaktu/ekstremalny poślizg/przeciążenie/brak ruchu, krótkie zakłócenia gotowości, POWER_PROBE z redukcją i blokadą powtórki, odrębny limit zmiany głównej.

Dokumentacja P1 pozostaje opisem historycznym. Parametry fizyki, zawias osi, COM oraz kalibracja ogumienia są bez zmian. Do testu użyć uzgodnionej kolejności z notatki wydania.
