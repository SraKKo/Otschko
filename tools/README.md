# Narzędzia ćwiczenia PC

Wymagany Python 3 oraz Godot 4.5.1 z szablonami eksportu Windows. Skrypt korzysta wyłącznie ze standardowej biblioteki Pythona.

Uruchom z katalogu projektu:

```powershell
python tools/pc_exercise.py all --godot "C:/sciezka/do/Godot.exe"
```

Oddzielne etapy:

```powershell
python tools/pc_exercise.py build --godot "C:/sciezka/do/Godot.exe"
python tools/pc_exercise.py verify
python tools/pc_exercise.py benchmark
```

`build` eksportuje debug i release do `builds/windows-debug` i `builds/windows-release`.
`verify` uruchamia dwa osobne procesy release: zapis przez kontrolki menu oraz sprawdzenie po restarcie. Sprawdza wyłączenie CRT w ustawieniach, menu głównym i rozgrywce. Tworzy zrzuty ekranu. Przywraca poprzedni plik preferencji użytkownika.
`benchmark` kolejno uruchamia obie aplikacje poza edytorem, wymusza 1280 x 720, wyłączony VSync, brak limitu FPS i włączony CRT. Przygotowuje tę samą rękę kart (stałe ziarno generatora) i zatrzymuje licznik czasu rundy. Po 5 sekundach rozgrzewki mierzy 30 sekund. Wcześniej sprawdza logi prawdziwej wygranej i pauzy. Sterowanie jest wyłączone na czas testu.

Na czas pomiaru okno pozostaje na wierzchu, z wyłączonym przyciskiem minimalizacji i maksymalizacji. Nie używaj funkcji Pokaż pulpit, nie zasłaniaj okna i nie zmieniaj obciążenia komputera. Dla najbardziej miarodajnego wyniku zamknij edytor i inne uruchomione gry przed wywołaniem `benchmark`.

Skrypt odrzuca test, jeśli nie wyrenderowano co najmniej 95% zmierzonych klatek, czas był krótszy niż 30 s, ustawienia obu procesów się różnią, występują błędy/ostrzeżenia, brakuje [DEV] w debug albo [DEV] występuje w release. Wyniki zapisuje w `reports/benchmark-*.json`, `comparison.json` i `wynik_pomiaru.txt`.

Średni FPS = liczba klatek / rzeczywisty czas pomiaru.
1% low = 1 / średni czas 1% najwolniejszych klatek (liczba klatek zaokrąglona w górę).
Zmiana procentowa = (FPS_release - FPS_debug) / FPS_debug * 100%.

Dane gracza: `%APPDATA%/Godot/app_userdata/blackjack/settings.cfg`.
Zwykły log gry: `%APPDATA%/Godot/app_userdata/blackjack/logs/godot.log`.
Logi z automatycznego porównania są rozdzielone: `reports/debug-godot.log` i `reports/release-godot.log`.

Do przekazania gry skopiuj cały wybrany katalog z `builds`: plik `.pck` musi pozostać obok `.exe`. Wersja debug zawiera również `.console.exe` do wyświetlenia konsoli. Wersja release nie wymaga edytora ani instalacji Godot.

API okien i tryby minimalizacji opisuje [dokumentacja Godot 4.5](https://docs.godotengine.org/en/4.5/classes/class_displayserver.html).
