# Ćwiczenie 2 - Obsługa kontrolerów z różnych platform

Projekt: blackjack / Otshcko!  
Data: 27.10.2026  
Godot 4.5.1, Windows x86_64. Wykonano implementację punktów 1-10; zakres testów sprzętowych opisano poniżej.

## Wprowadzone funkcje

- Wspólne akcje InputMap dla klawiatury i pada: rozdanie, dobranie, pas, podział ręki, zmiana zakładu oraz pauza. Przyciski z UI i akcje urządzeń wywołują te same istniejące funkcje gry.
- Last input wins: znaczący ruch gałki, naciśnięcie przycisku, klawisza lub ruch myszy przełącza aktywne urządzenie bez ustawień i restartu. Zwolnienie przycisku nie przełącza urządzenia.
- Martwa strefa gałek: 0,35. Ruch myszy mniejszy niż 3 piksele w zdarzeniu jest pomijany podczas wyboru urządzenia, aby ograniczyć przełączanie od drgań.
- Etykieta aktywnego urządzenia w prawym górnym rogu oraz dopasowane teksty i ikona akceptacji/rozdania. Xbox pokazuje zielone A, PlayStation rysowany krzyżyk, Switch czerwone B, a nieznany pad neutralny symbol. Ikony są rysowane wektorowo i nie wymagają obecności symboli PlayStation w czcionce.
- Rozpoznawanie rodziny po nazwie kontrolera przekazanej przez Godot; bezpieczny zestaw ogólny dla nierozpoznanych urządzeń. Obsługiwany jest dowolny identyfikator pada, nie tylko urządzenie 0.
- Hot-plug przez `Input.joy_connection_changed`. Podłączenie nie przejmuje sterowania od dotychczasowego urządzenia; dopiero użycie pada je przełącza.
- Odłączenie aktywnego pada w rozgrywce pauzuje grę i pokazuje „Podłącz kontroler lub użyj klawiatury”. Odłączenie nieaktywnego pada nie zatrzymuje gry. Ponowne podłączenie ukrywa komunikat, ale nie wznawia rozgrywki. Znaczące wejście klawiaturą/myszą również usuwa komunikat, pozostawiając pauzę do decyzji gracza.
- Na życzenie użytkownika kursor jest widoczny i można klikać myszą również podczas rozgrywki. Przy sterowaniu padem pozostaje ukryty; znaczący ruch myszy przywraca go w grze, menu i pauzie. To świadoma zmiana względem pierwotnego wymagania przechwytywania kursora z punktu 6 ćwiczenia.
- Nawigacja bez myszy: menu główne, ustawienia, pauza, napisy, ekran końca gry/zwycięstwa oraz wybór nagrody mają fokus. Złota ramka wskazuje wybrany element. Krzyżak i lewa gałka służą do nawigacji; w ustawieniach można zmieniać opcje, suwaki i CRT padem.
- Krótkie wibracje przy wyniku rundy: 0,22 s, siła słabego silnika 0,35, mocnego 0,6. Przełącznik „Controller vibration” wyłącza wibracje i zapisuje wybór w `settings.cfg`. Zmiana aktywnego pada zatrzymuje wibracje poprzedniego.

**Decyzja o obszarach hot-plug (punkt 8):** przełączanie urządzeń działa w menu, ustawieniach, rozgrywce, pauzie i wyborze nagrody, a jest zablokowane podczas automatycznego benchmarku oraz w jawnie zablokowanej strefie `switching_enabled = false`.

## Sterowanie

Nazwy przycisków dotyczą standardowego mapowania Godot i ich fizycznego położenia. Switch używa fizycznego dolnego B do akceptacji, zgodnie z tym samym układem akcji co Xbox i PlayStation; podpowiedzi wyświetlają właściwe oznaczenie.

| Akcja | Klawiatura | Xbox | PlayStation | Switch |
| --- | --- | --- | --- | --- |
| Rozdaj | Spacja | A | Krzyżyk | B |
| Dobierz | H | X | Kwadrat | Y |
| Pas / zakończ rękę | J | B | Kółko | A |
| Podziel parę | K | Y | Trójkąt | X |
| Zakład -10 / +10 | Q / E | LB / RB | L1 / R1 | L / R |
| Pauza / wznowienie | Esc | Menu/Start | Options | + |
| Nawigacja w menu | Strzałki / Tab | Krzyżak / lewa gałka | Krzyżak / lewa gałka | Krzyżak / lewa gałka |
| Akceptacja w menu | Enter / Spacja | A | Krzyżyk | B |
| Wstecz / wyjście z pauzy | Esc | B | Kółko | A |

Podczas rozgrywki można używać myszy do klikania przycisków, wymienionych skrótów klawiatury albo pada. Wybór nagrody wymaga wskazania nagrody; Wstecz nie pomija nagrody. Na głównym ekranie Wstecz nie zamyka gry - służy do tego przycisk Quit.

## Sprawdzenia i dowody

- Wyeksportowano i uruchomiono debug oraz release jako samodzielne aplikacje Windows.
- Debug: **50/50** sprawdzeń zakończonych powodzeniem.
- Release: **50/50** sprawdzeń zakończonych powodzeniem.
- Testy używają `Input.parse_input_event()` i tych samych metod obsługujących sygnał podłączenia/odłączenia. Obejmują rozpoznawanie nazw, martwe strefy, prawdziwe przejścia menu, obsługę zakładu/rozdania/dobrania/podziału/pasu, wybór nagrody, zmianę ikon i tekstów, blokadę strefy, odłączenie nieaktywnego i aktywnego pada, brak automatycznego wznowienia, powrót do klawiatury oraz żądania wibracji i zapis przełącznika.
- Dodatkowo sprawdzono rzeczywiste kliknięcia myszą przycisków zakładu w rozgrywce oraz przywracanie widocznego kursora po przejściu z pada na mysz.
- Sprawdzono regresyjnie zapis i odczyt ustawień z ćwiczenia 1, w tym działanie CRT po restarcie.
- Końcowe logi testów obu eksportów nie zawierają błędów ani ostrzeżeń. Komunikaty `[DEV]` występują tylko w debug.
- Obejrzano zrzuty menu, ustawień, rozgrywki oraz komunikatu odłączenia. Podpowiedzi w grze znajdują się pod paskiem czasu i nie zasłaniają dolnych przycisków.
- Testy odtwarzają poprzedni plik ustawień użytkownika po zakończeniu.

**Ograniczenie weryfikacji sprzętowej:** system nie wykrył żadnego fizycznie podłączonego kontrolera. Nie wykonano rzeczywistego testu USB/Bluetooth, fizycznego działania silniczków wibracji ani porównania dwóch fizycznych modeli. Testy integracyjne potwierdzają logikę gry i reakcje UI, ale nie zastępują testu na sprzęcie. Jeżeli Steam Input lub inny pośrednik przedstawia pad jako wirtualnego Xboxa, gra pokaże rodzinę zgłoszoną przez ten pośrednik, nie ukrytą markę fizycznego urządzenia.

Pliki dowodowe:

- `reports/controllers/debug-checks.json` i `release-checks.json`: wyniki wszystkich sprawdzeń oraz lista wykrytych fizycznych padów.
- `reports/controllers/debug-runtime.log`, `release-runtime.log` oraz odpowiadające im `*-godot.log`: logi obu aplikacji.
- `reports/controllers/controller-xbox-menu.png`, `controller-settings.png`, `controller-playstation-game.png`, `controller-playstation-pause.png`, `controller-disconnected.png`, `controller-keyboard-pause.png`: zrzuty ekranu z testów.

## Powtórzenie testów

Wymagany Python 3 i Godot 4.5.1 z szablonami Windows:

```powershell
python tools/controller_exercise.py all --godot "C:/sciezka/do/Godot.exe"
```

Sprawdzenie już gotowych eksportów:

```powershell
python tools/controller_exercise.py verify
```

Do końcowego testu sprzętowego podłącz pada i wykonaj: ruch gałką w menu -> nawigacja i rozpoczęcie gry -> odłączenie -> sprawdzenie pauzy i komunikatu -> ponowne podłączenie -> ręczne wznowienie -> wynik rundy z wibracją -> wyłączenie wibracji w ustawieniach -> ponowny wynik. Następnie porusz myszą w menu oraz, jeśli dostępny, podłącz pad innego producenta i sprawdź podpowiedzi.

Gotowe aplikacje znajdują się w `builds/windows-debug` i `builds/windows-release`. Plik `.pck` musi pozostać obok `.exe`. Obie wersje obejmują funkcje ćwiczeń 1 i 2; wcześniejszy pomiar FPS z ćwiczenia 1 dotyczy stanu projektu sprzed dodania warstwy kontrolerów.

Główne pliki implementacji: `Scripts/ControllerInput.gd`, `Scripts/InputPromptIcon.gd`; testy: `Scripts/ControllerVerification.gd` i `tools/controller_exercise.py`.

Dokumentacja: [Input i sygnał podłączenia](https://docs.godotengine.org/en/4.5/classes/class_input.html), [obsługa wejścia w Godot](https://docs.godotengine.org/en/4.5/tutorials/inputs/).
