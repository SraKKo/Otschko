# Ćwiczenie 3 - Zarządzanie użytkownikami w grze

Projekt: blackjack / Otshcko!  
Data wykonania: 04.11.2026  
Silnik: Godot 4.5.1, Windows x86_64.

Wykonano minimum i podstawę ćwiczenia (punkty 1-7). Platforma jest lokalną symulacją; nie podłączono Steam, Xbox ani prawdziwej usługi logowania z rozszerzenia 8.

## Korzystanie z funkcji

1. Uruchom grę i naciśnij dowolny klawisz, przycisk myszy lub pada. Ruch myszy i drgnięcie gałki nie przypisują użytkownika.
2. Wybierz profil Ala lub Olek. Możesz też wpisać nazwę i użyć „UTWÓRZ PROFIL”. Nazwa ma 1-24 znaki; puste i powtarzające się nazwy są odrzucane. Nowy profil wybiera się z listy po utworzeniu.
3. Nazwa głównego gracza jest widoczna w menu i podczas gry. Menu pokazuje jego własne statystyki.
4. Przycisk „ZMIEŃ UŻYTKOWNIKA” w menu przechodzi do wyboru profilu, czyści stan poprzedniej sesji i ładuje dane wskazanego użytkownika. Wstecz na ekranie profili wraca do ekranu „Naciśnij dowolny przycisk”, umożliwiając wybór innego urządzenia.
5. **F8** symuluje wylogowanie przez platformę: zapisuje dotychczasowe statystyki, usuwa głównego gracza, urządzenie i gracza dodatkowego oraz wraca do menu głównego w stanie niezalogowanym. Przycisk „ZALOGUJ SIĘ” lub Play otwiera wybór profilu, a ustawienia i napisy pozostają dostępne bez logowania. Usuwa również pauzę i ekwipunek poprzedniej sesji.
6. **F9** przełącza symulowaną dostępność sieci. Pojawia się komunikat „Tryb offline - zapis lokalny”. Gra działa dalej i zapisuje wyniki lokalnie. Po ponownym F9 komunikat znika. Przełączanie profili i wylogowanie nie kasują statystyk w trybie offline.
7. Naciśnięcie przycisku na urządzeniu innym niż urządzenie właściciela dołącza drugiego użytkownika. Automatycznie wybierany jest pierwszy profil inny od głównego, a jego nazwa pojawia się obok nazwy gracza 1. Dołączenie nie pauzuje gry. Pierwszy przycisk dołączającego nie wykonuje równocześnie akcji rozgrywki. Klawiatura i mysz są jednym wspólnym urządzeniem.

F8 i F9 są przyciskami symulacji platformy, dlatego nie dołączają drugiego użytkownika i nie przejmują własności sesji. Kolejne uruchomienie aplikacji zaczyna się od wyboru profilu, a symulacja sieci wraca do stanu online.

## Własność sesji i urządzenia

Urządzenie użyte na ekranie startowym jest zapamiętywane jako urządzenie głównego użytkownika: klawiatura/mysz albo konkretny identyfikator pada. Wybór innego aktywnego urządzenia w ramach last input wins z ćwiczenia 2 nie zmienia właściciela sesji. Podczas zmiany użytkownika urządzenie użyte do wywołania zmiany staje się kandydatem dla nowej sesji; można wrócić do ekranu startowego i wybrać inne.

Dodatkowy użytkownik jest uczestnikiem sesji w zakresie wymaganym przez ćwiczenie: ma nazwę i powiązanie z urządzeniem. Gra zachowuje jedną rozgrywkę blackjacka i zapisuje jej wyniki dla głównego użytkownika; nie dodano oddzielnych rąk, portfeli ani trybu kooperacji dla gracza 2. Późniejsze wejścia innych urządzeń pozostają zgodne z dotychczasowym przełączaniem sterowania. Odłączenie urządzenia dodatkowego użytkownika usuwa go z sesji.

## Oddzielne dane profili

Każdy profil ma osobno zapisywane:

- liczbę zakończonych rund,
- liczbę zwycięstw,
- najwyższy osiągnięty etap,
- rekord liczby żetonów.

Zmiana użytkownika wczytuje te statystyki z jego pliku i pokazuje je w menu. Nowa rozgrywka nadal zaczyna się z 500 żetonami. Zapis obejmuje statystyki profilu, a nie wznawianie rozdanej ręki ani pełnego przebiegu kampanii. Ustawienia obrazu, dźwięku, CRT i wibracji pozostają wspólnymi ustawieniami urządzenia z wcześniejszych ćwiczeń.

Statystyki zapisują się od razu po rozliczeniu rundy oraz przy wylogowaniu, niezależnie od symulacji sieci. Blokada podwójnego raportowania zapobiega ponownemu naliczeniu tej samej rundy. Nazwa użytkownika nie jest używana jako nazwa pliku: nowe profile otrzymują losowy identyfikator. Zapis wykorzystuje plik tymczasowy i zmianę nazwy po zapisie; błąd zapisu jest widoczny w UI.

Dane zwykłej gry:

```text
%APPDATA%\Godot\app_userdata\blackjack\profiles\profiles.json
%APPDATA%\Godot\app_userdata\blackjack\profiles\ala.json
%APPDATA%\Godot\app_userdata\blackjack\profiles\olek.json
```

Nowe profile mają pliki o nazwach `user_<losowy_id>.json`. `profiles.json` przechowuje listę nazw i identyfikatorów. Jest to lokalna symulacja profili, bez haseł i autoryzacji usług zewnętrznych.

## Implementacja

`UserSession.gd` jest centralnym Autoloadem: przechowuje właściciela, urządzenie główne, dodatkowego gracza, stan sieci i statystyki. Udostępnia zdarzenia `logged_in`, `logged_out`, `secondary_joined`, `session_changed`, `network_changed` oraz `progress_changed`. Etykiety reagują na te sygnały; zapis wyników trafia do pliku bieżącego właściciela. Ekran wejścia i wyboru profilu znajduje się w `ProfileGate.tscn` i `profile_gate.gd`.

Zachowano obsługę myszki podczas rozgrywki, mapowanie padów, pauzę po odłączeniu pada, opcję CRT oraz zapis ustawień z ćwiczeń 1 i 2.

## Weryfikacja

- **Debug: 62/62** sprawdzeń profili (52 w procesie zapisującym i 10 w osobnym procesie odczytującym).
- **Release: 62/62** takich samych sprawdzeń.
- Każdy wariant startuje ponownie w oddzielnym procesie i odczytuje dane utworzone przez poprzedni proces: wynik Ali, niezależny wynik Olka i nowy profil Marta.
- Testy obejmują ekran wejścia, przypisanie konkretnego pada, powrót do wyboru urządzenia, wybór profilu padem i klawiaturą, zapis po rzeczywistej wygranej/przegranej, F8 podczas pauzy, F9 bez utraty danych, zmianę użytkownika, walidację nazwy, tworzenie profilu i dołączenie gracza 2 zarówno do sesji pada, jak i klawiatury.
- Regresja sterowania: **50/50** sprawdzeń w debug i **50/50** w release, w tym klikanie myszą podczas gry.
- Osobny test zapisu ustawień i restartu, w tym CRT: zaliczony.
- Końcowe logi testów profili oraz sterowania nie zawierają błędów ani ostrzeżeń.
- Zrzuty ekranu startowego, wyboru profili, menu, trybu offline i dołączenia gracza 2 zostały obejrzane.

Testy używają syntetycznych zdarzeń wejścia Godot i izolowanych katalogów profili w `reports/users`, dzięki czemu nie nadpisują właściwych profili gracza. Testy starszych ćwiczeń używają przejściowej sesji w pamięci, bez zapisu do rzeczywistych profili. W systemie nie wykryto fizycznego pada; testy urządzeń potwierdzają logikę identyfikatorów i zdarzeń, nie rzeczywiste połączenie USB/Bluetooth. F8 i F9 są celowo symulacją zgodnie z poleceniem.

Wyniki: `reports/users/debug-write-checks.json`, `debug-read-checks.json`, `release-write-checks.json`, `release-read-checks.json`. Logi znajdują się obok, w plikach `*-runtime.log` i `*-godot.log`. Podsumowanie: `reports/users/summary.json`.

## Powtórzenie

Pełny eksport i sprawdzenia obu wariantów:

```powershell
python tools/user_exercise.py all --godot "C:/sciezka/do/Godot.exe"
```

Sprawdzenie gotowych eksportów:

```powershell
python tools/user_exercise.py verify
```

Gotowa gra: `builds/windows-release/Blackjack.exe`; wariant deweloperski: `builds/windows-debug/Blackjack.exe`. Plik `.pck` musi pozostać obok `.exe`.
