from pathlib import Path

p = Path("CHANGELOG.md")
s = p.read_text(encoding="utf-8")
start = s.find("## 1.1.1.0\n")
end = s.find("# Changelog konwersji FS22 → FS25\n")
if start != 0 or end == -1 or end <= start:
    raise SystemExit("unexpected CHANGELOG.md structure")

entry = '''## 1.1.1.0
Pełne wydanie po serii testowej 1.0.6.0T1-T14. Wersja nie jest traktowana jako w pełni kompatybilna z linią 1.0.x ze względu na zmianę fizyki masy, układu napędowego i sposobu konfiguracji skrzyni biegów.

Najważniejsze zmiany:
- konfigurację silnika `1934 Robert` przemianowano na `1934 Widmo`; techniczne nazwy plików kół Robert pozostają bez zmian,
- realistyczny układ masy zwykłych wariantów: component #1 `3720 kg`, component #2 `1340 kg`, bazowy COM `0 0.80 -0.88`; test runtime na podstawowych kołach i pełnym zbiorniku potwierdził około `6.183 t` masy roboczej i około `39.9/60.1` przód/tył,
- `1934 Widmo` zachowuje własny układ `3700/2500 kg`, COM `0 1.10 -1.80`, 290 KM i około `30.1/69.9` przód/tył na podstawowych kołach,
- poprawiono fizykę przednich balastów 600/1200/1500/2000 kg: dodają rzeczywistą masę do głównego komponentu, a wpływ na COM jest liczony jako średnia ważona; Widmo korzysta przy tym ze swojej osobnej bazy masy i COM,
- dodano niezależny wybór skrzyni w sklepie: `Fabryczna` 16/8 (8/4 × L/H) albo `Bez wzmacniacza` 8/4,
- dodano niezależny wybór układu napędowego w sklepie: `Fabryczny` 4x4 albo `Odłączenie przedniej osi` (RWD),
- `1934 Widmo` zachowuje ręczne przełączanie RWD ↔ 4x4 przez remapowalną akcję `URSUS_WIDMO_TOGGLE_4WD`, domyślnie `Ctrl+4`; fizykę dyferencjałów przebudowuje serwer,
- dodano zależną od obciążenia, natywną regulację zawieszenia dla całej rodziny Ursusa przez `WheelPhysics:setSuspensionMultipliers()`, bez sztucznego `addForce`/`addTorque`: tył do `spring ×1.15 / damping ×0.60` przy około `1.60×` obciążenia spoczynkowego, przód do `spring ×1.10 / damping ×0.75` przy około `1.50×`,
- `1934 Widmo`: tylna trakcja wzdłużna `maxLongStiffness ×1.20`, boczna `maxLatStiffness ×0.85` i `forcePointRatio=0.80`; ma to zachować uciąg, a zmniejszyć skłonność do przewracania przez zbyt dużą przyczepność boczną,
- ceny nowych modyfikacji: `Bez wzmacniacza` +5000, `Odłączenie przedniej osi` +2500, `1934 Widmo` +40000; warianty fabryczne skrzyni i napędu pozostają bez dopłaty,
- diagnostyka T13/T14 potwierdziła docelowy rozkład masy i została usunięta z pełnego wydania wraz z tymczasowym logowaniem testowym,
- masy i pliki konfiguracji kół nie były sztucznie kompensowane przez skrypt; ich natywne dodatkowe masy pozostają obsługiwane przez system kół GIANTS.

Kompatybilność z 1.0.x:
- 1.1.1.0 zmienia bazową masę i rozkład masy zwykłych wariantów oraz dodaje nowe konfiguracje skrzyni i napędu, dlatego nie jest traktowane jako w pełni zgodne zachowaniem z wcześniejszymi wydaniami 1.0.x,
- pozostałe wcześniej zatwierdzone systemy, m.in. kolizje, TUZ/WOM, zaczepy, tankowanie, lusterka, światła, hydraulika, animacje i kolorowanie, pozostają zachowane.

Znane problemy:
- `Ursus1934.i3d` może zgłaszać zaakceptowany warning `non-binary indexed triangle sets`; źródłem pozostaje tekstowo zapisana geometria `FS25MirrorExact`, a warning nie powoduje zaobserwowanych problemów z działaniem ani wyglądem moda,
- ręczny stan przełącznika RWD/4x4 Widma nie jest zapisywany osobno w savegame; po ponownym wczytaniu pojazd rozpoczyna od stanu wynikającego z konfiguracji napędu wybranej w sklepie.

'''

p.write_text(entry + s[end:], encoding="utf-8")
print("Completed CHANGELOG.md entry for 1.1.1.0")
