# TODO / dalszy rozwój

Notatki do kolejnych wersji po 1.1.1.0.

## Lusterka

- Dodać działające lusterka również w widoku TPS / kamerze zewnętrznej.
- Nie naruszać zatwierdzonej geometrii i ustawień lusterek z obecnego widoku FPS bez osobnego testu regresji.

## Napęd i konfiguracje

- Dodać możliwość ręcznego przełączania napędu przedniej osi (RWD ↔ 4x4) dla każdej wersji ciągnika, nie tylko dla 1934 Widmo.
- Przełączanie ma faktycznie przebudowywać fizyczny układ napędowy / dyferencjały, a nie być wyłącznie zmianą wizualną lub parametrem pomocniczym.
- Zachować poprawną synchronizację multiplayer po stronie serwera i klientów.

## Rozdzielenie Widmo / skrzyni / napędu

- `1934 Widmo` powinno być wyłącznie wariantem silnika / charakterystyki silnika i jego własnego strojenia fizyki.
- Typ skrzyni biegów powinien pozostać niezależną opcją konfiguracyjną dostępną także dla Widmo.
- Konfiguracja przedniego napędu / przedniego dyferencjału powinna pozostać niezależną opcją konfiguracyjną, również dla Widmo.
- Docelowo wybór silnika, skrzyni oraz układu napędowego nie powinien być ze sobą sztucznie sprzężony.
