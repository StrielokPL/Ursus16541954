# V25 reference

Ten katalog opisuje dokładnie testowany pakiet:

`FS25_Ursus_1654_1954_Pack_V25_COLLISION_FILTERS_TEST.zip`

- Google Drive ID: `1YooVa2-ZpJYeYRnjX1a9eWCWh-TvWe01`
- rozmiar: `33320116` B
- SHA-256 ZIP-a: `e6b5be7809c36c00da5d9543906732cd3ce05c0a80da75d93484c3f0e9917b38`
- liczba plików gry: `67`

`files.txt` jest allowlistą używaną przez builder. `SHA256SUMS.txt` zawiera SHA-256 zawartości wszystkich 67 plików i służy do weryfikacji bazowego V25.

`python3 tools/verify_v25.py` sprawdza bieżące pliki repo względem tej referencji. Po rozpoczęciu zmian V26 różnice w zmodyfikowanych plikach są oczywiste i oczekiwane; builder nadal korzysta z `files.txt`.
