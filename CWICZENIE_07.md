# Ćwiczenie 7 — DRM i wykrywanie oszustw

## Jak sprawdzić w grze

1. Uruchom grę i wybierz profil. Ekran **Licencja gry** blokuje wejście przy braku klucza. **Kup grę (symulacja)** pobiera i aktywuje klucz w przestrzeni `51796`. **Aktywuj klucz** przyjmuje istniejący klucz. Operacje te używają usługi uczelnianej.
2. W menu otwórz **Licencja**, skopiuj klucz i spróbuj go aktywować na innym profilu. Licencja jest przypisana do nazwy konta.
3. Po weryfikacji naciśnij **F9**, zamknij grę i uruchom ją ponownie. Ten sam profil może wejść przez siedem dni od ostatniego sprawdzenia. Profil bez weryfikacji pozostaje zablokowany. Kolejne naciśnięcie **F9** przywraca połączenie.
4. W kompilacji debug rozpocznij rozgrywkę i naciśnij **F7**. Gra wykrywa zmianę chronionych żetonów, zeruje portfel, wyświetla komunikat i zapisuje zdarzenie w logu.
5. Zagraj rundę i zamknij grę. W kopii profilu zmień liczbę w polu `payload` pliku zapisu `<id>.json`, zostawiając dotychczasowy HMAC. Przy następnym logowaniu gra odrzuci zapis i pokaże komunikat. Jeśli chmura ma poprawną kopię, mechanizm Roaming Save może ją odtworzyć. Pierwszy odczyt pliku ze starszej wersji podpisuje go na miejscu.
6. Otwórz **Zapis w chmurze → Żetony premium**. **Dodaj 50** aktualizuje osobny licznik serwerowy. W debug **Test: dodaj 5000** wyświetla odmowę. Te przyciski wysyłają żądania zapisu do usługi uczelnianej.
7. Wersję Web serwuj z całego katalogu `builds/web`. Dozwolone są loopback, `itch.io`, `itch.zone` i ich subdomeny hostingowe. Gra odczytuje domenę ramki, w której się uruchamia.

## Test lokalny i ograniczenia

`python tools/drm_exercise.py` eksportuje Windows debug, Windows release i Web oraz przeprowadza scenariusze z odizolowaną kopią profili. W symulacji licencji i licznika żetonów używa wyłącznie `127.0.0.1`. Raporty DRM znajdują się w `reports/07-*-godot.log`. Testy ćwiczeń 3 i 4 uruchamiają tryby weryfikacyjne w kompilacji debug lub edytorze. Ekrany wersji Web w Edge zapisano jako: `07-web-127.0.0.1.png`, `07-web-license.png` oraz `07-web-copied.example.png` w katalogu `reports`.

Maska, suma kontrolna, HMAC i blokada domeny działają w kliencie. Zmodyfikowany klient może je obejść. Osobny licznik premium wymaga połączenia i egzekwuje limit ±100 na operację. Gra nadal rozlicza stawkę i wygraną zwykłych żetonów lokalnie, dzięki czemu rozgrywka działa offline. Lokalne profile symulują konta platformy i identyfikują użytkowników nazwą.
