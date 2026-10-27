# Ćwiczenie 1 - Port na platformę PC

Projekt: blackjack / Otshcko!  
Data wykonania: 27.10.2026  
Silnik: Godot 4.5.1-stable (official), Windows x86_64, Forward+ / Vulkan.

## Wykonany zakres

Wykonano minimum i podstawę (punkty 1-5) oraz rozszerzenia 6 i 10.

1. Dwie samodzielne aplikacje Windows: `builds/windows-debug/Blackjack.exe` i `builds/windows-release/Blackjack.exe`. Obie wyeksportowano i uruchomiono jako osobne procesy bez korzystania z uruchamiania gry w edytorze. Każda aplikacja potrzebuje pliku `Blackjack.pck` znajdującego się obok niej. Debug ma dodatkowo `Blackjack.console.exe` otwierający konsolę.
2. Licznik FPS i czasu klatki widoczny w każdej scenie. Odświeżanie co 0,5 s; pomiar przez monotoniczny zegar `Time.get_ticks_usec()`, niezależny od pauzy i skali czasu. Licznik działa również podczas pauzy.
3. Wpisy `[DEV]` obejmują start gry, wczytanie GameProper, wynik/wygraną i stan pauzy. `OS.is_debug_build()` warunkuje zapis. Log debug potwierdza te zdarzenia, a log release nie zawiera `[DEV]`. Kod GDScript pozostaje częścią projektu release, ale nie zapisuje tych komunikatów.
4. Rzeczywiste pomiary po 30 sekund w obu eksportach, z wyłączonym VSync i limitem klatek. Wyniki i różnica procentowa poniżej.
5. Zapisywane ustawienia PC: cztery rozdzielczości okna (1152 x 648, 1280 x 720, 1600 x 900, 1920 x 1080), pełny ekran i VSync. F11 przełącza pełny ekran. Wybrana rozdzielczość dotyczy trybu okna; pełny ekran korzysta z rozmiaru ekranu.
6. Dodatkowo naprawiono przełącznik filtra CRT: można go włączyć i wyłączyć, podgląd zmienia się natychmiast, a stan jest zapisywany i stosowany w kolejnych scenach oraz po restarcie. Zachowano regulację głośności.
7. Z rozszerzeń wydajności wykonano pomiar 1% low.

Opcjonalne punkty 7-9 z polecenia (zmiana przypisania klawiszy, drugi komputer, inne konfiguracje kompilacji/backendy) nie były wykonywane.

## Porównanie wydajności

Przy wyłączonym VSync i limicie FPS, w tej samej scenie GameProper (1280 x 720, CRT włączony), przez 30 s po 5 s rozgrzewki zmierzono średnio 1794.96 FPS w debug i 1824.86 FPS w release, co daje zmianę +1.67% względem debug.

| Wersja | Czas pomiaru | Klatki procesu | Wyrenderowane klatki | Średni FPS | 1% low FPS |
| --- | ---: | ---: | ---: | ---: | ---: |
| Debug | 30.000 s | 53849 | 53849 | 1794.96 | 270.93 |
| Release | 30.001 s | 54747 | 54747 | 1824.86 | 200.18 |

Wzór: `(FPS_release - FPS_debug) / FPS_debug * 100%`.
1% low: odwrotność średniego czasu 1% najwolniejszych klatek; liczbę klatek zaokrąglono w górę.

Sprzęt: 12th Gen Intel(R) Core(TM) i5-12400F; NVIDIA GeForce RTX 4060. Oba pomiary: scena `GameProper`, 1280 x 720, CRT włączony, VSync = 0, limit FPS = 0. Przed pomiarem 5 s rozgrzewki. Generator z ziarnem 20261027 zapewnia tę samą rękę kart; zegar rundy jest zatrzymany, sterowanie nie zmienia sceny podczas testu. Przed rozgrzewką test wywołuje prawdziwe zdarzenia wygranej oraz pauzy i wznowienia.

W końcowym teście okna były widoczne, a kontrola liczby wyrenderowanych klatek przeszła dla obu procesów. Wcześniejszą próbę ze zminimalizowanym oknem odrzucono. Tryb benchmarku utrzymuje okno na wierzchu i wyłącza przyciski minimalizacji/maksymalizacji; zwykła gra zachowuje standardowe działanie okna.

To pojedyncza para lokalnych pomiarów. W tle pozostawał otwarty edytor oraz wcześniejsza sesja gry użytkownika; wynik nie jest pomiarem na całkowicie bezczynnym komputerze. Różnica 1,67% może mieścić się w zmienności kolejnych prób. Dla oceny samego wpływu debug/release należy zamknąć dodatkowe aplikacje i powtórzyć pomiary kilka razy. Skrypt do powtórzenia jest dołączony.

## Sprawdzenia

- Eksporty debug i release: powodzenie, oba uruchomione jako samodzielne aplikacje.
- Log debug zawiera start, poziom, wygraną i pauzę; log release nie zawiera wpisów `[DEV]`.
- Końcowe logi uruchomień i testów ustawień: brak błędów i ostrzeżeń.
- Menu ustawień przetestowano przez rzeczywiste kontrolki. Osobny proces po restarcie potwierdził zapis CRT, VSync, pełnego ekranu i rozdzielczości oraz ukrycie CRT w ustawieniach, menu i rozgrywce.
- Zrzuty `reports/settings-crt-on.png` i `reports/settings-crt-off.png` potwierdzają wygląd; oba obejrzano.
- Test ustawień odtwarza poprzedni plik preferencji użytkownika po zakończeniu.
- Poprawiono też pustą teksturę ViewportTexture w tytule menu oraz własność węzła talii kart, aby zwalniał się z rozgrywką. Test czeka na zwolnienie odtwarzanych dźwięków przed zamknięciem.

## Pliki dowodowe i powtórzenie

- `reports/benchmark-debug.json`, `benchmark-release.json`, `comparison.json`: surowe wyniki i dane środowiska.
- `reports/wynik_pomiaru.txt`: jedno zdanie do notatki końcowej.
- `reports/debug-godot.log`, `release-godot.log`: rozdzielone logi aplikacji.
- `reports/settings-write.log`, `settings-read.log`: potwierdzenie testu zapisu i restartu.
- `reports/export-debug.log`, `export-release.log`: zapis eksportu.
- `tools/pc_exercise.py`: automatyczny eksport, sprawdzanie ustawień i pomiar. Instrukcja: `tools/README.md`.

Powtórzenie pełnego procesu:

```powershell
python tools/pc_exercise.py all --godot "C:/sciezka/do/Godot.exe"
```

Preferencje zapisują się w `%APPDATA%/Godot/app_userdata/blackjack/settings.cfg`. Zwykły log aplikacji znajduje się w podkatalogu `logs/godot.log`. Katalogi z eksportami są wyłączone ze śledzenia Git oraz z zasobów kolejnych eksportów.

Dokumentacja API okna: https://docs.godotengine.org/en/4.5/classes/class_displayserver.html
