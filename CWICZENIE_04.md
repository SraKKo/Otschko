# Ćwiczenie 4 - Roaming Save / zapis w chmurze

Projekt: blackjack / Otshcko!  
Przestrzeń: **51796**  
API: `https://dsw-cloud.dsw-ppdg.workers.dev/v1`.

Implementacja odpowiada minimum i podstawie (punkty 1-7) oraz zachowuje osobne dane istniejących profili. Rzeczywista wysyłka testowa do usługi uczelnianej oczekuje na zgodę użytkownika. Dotychczas wykonano **0 zapisów i 0 usunięć danych w prawdziwej chmurze**.

## Zapis jednym kliknięciem

Przycisk „ZAPISZ W CHMURZE” od razu wysyła bieżący zapis, bez dodatkowego okna potwierdzenia. Samo otwarcie panelu chmury nie wykonuje wysyłki. Zapis lokalny działa niezależnie, a niezmienione, zsynchronizowane dane nie są ponownie wysyłane.

Okno decyzji pozostaje przy rzeczywistym konflikcie. „ZACHOWAJ TEN KOMPUTER I ZAPISZ” wysyła wybraną wersję lokalną względem najnowszej znanej wersji serwera; „ZACHOWAJ ZAPIS Z CHMURY” przyjmuje dane serwera. W razie kolejnego konfliktu 409 gra ponownie pokazuje obie wersje, zamiast nadpisywać je po cichu. Nie ma automatycznych ponowień POST.

Po powrocie sieci gra odczytuje stan chmury. Oczekujące dane można wysłać przyciskiem Zapisz. Nowe zmiany powstałe podczas trwającego żądania pozostają lokalnie do kolejnego zapisu.

Testy wykonywane przez asystenta są lokalne. Zmiana interfejsu gry nie stanowi zgody na osobny zapis testowy asystenta do prawdziwej usługi.

## Dane i cykl synchronizacji

Przenoszone są statystyki z ćwiczenia 3: liczba rund, zwycięstw, najwyższy etap i rekord żetonów. Zapis nie obejmuje odtworzenia rozdanej ręki. Format wartości chmurowej to mały JSON `schema: 1` z obiektem `progress`; bez nazw użytkowników i innych danych osobowych.

Każdy lokalny plik profilu zawiera metadane `cloud`:

- `base_version`: ostatnia wersja potwierdzona przez serwer,
- `dirty`: obecność niewysłanych lokalnych zmian,
- `revision`: numer lokalnej migawki, który chroni zmiany powstałe w trakcie żądania,
- `saved_at`: informacyjny czas lokalnego zapisu,
- `server_updated_at`: informacyjny czas z serwera.

Przy logowaniu wykonywany jest GET dla wybranego profilu i klucza `save`. Po porównaniu wersji gra wybiera: nową grę, pobranie nowszego zapisu, zgodność, oczekiwanie na kliknięcie Zapisz lub konflikt. Porównanie nie zależy od zegara komputera; daty w oknie decyzji są opisane jako UTC i służą wyłącznie jako informacja.

Każdy POST zawiera `expectedVersion` równe wersji bazowej. Nie używamy `expectedVersion=-1`. Odpowiedź 409 otwiera okno konfliktu i zachowuje oba warianty bez automatycznego nadpisania. Opóźniona odpowiedź dla poprzedniego profilu nie jest stosowana do nowego użytkownika. Zmiany lokalne powstałe podczas wysyłki zachowują znacznik `dirty` i czekają na kolejny zapis.

## Korzystanie w grze

1. Zaloguj profil i rozegraj rundę. Statystyki zapiszą się lokalnie, a stan chmury będzie widoczny w menu.
2. Otwórz „ZAPIS W CHMURZE”. „SPRAWDŹ SYNCHRONIZACJĘ (ODCZYT)” nie zapisuje niczego na serwerze.
3. Kliknij „ZAPISZ W CHMURZE” - zapis zostanie wysłany bez dodatkowego potwierdzenia.
4. F9 symuluje brak sieci. Gra zapisuje lokalnie i zachowuje kolejkę. Po przywróceniu sieci pobiera stan serwera i czeka na kliknięcie Zapisz.
5. Konflikt pokazuje dane tego komputera oraz chmury. „ZACHOWAJ ZAPIS Z CHMURY” pobiera wybrany wariant do lokalnego pliku. „ZACHOWAJ TEN KOMPUTER I ZAPISZ” od razu wysyła wybraną wersję lokalną względem aktualnej wersji serwera.
6. „WYCZYŚĆ ZAPIS LOKALNY…” wymaga potwierdzenia. Usuwa tylko plik bieżącego profilu, zachowuje kopię zapasową i nie wysyła DELETE ani POST do usługi. Po restarcie albo ponownym logowaniu stan jest odtwarzany przez GET z chmury. Wylogowanie po czyszczeniu nie tworzy pustego zapisu, który mógłby zastąpić postęp.

Okna decyzji wspierają mysz, klawiaturę i pad. Na czas okna gra jest wstrzymana, a po zamknięciu przywracany jest poprzedni stan pauzy. F8 nadal wylogowuje i wraca do menu.

## Ścieżki i kopie bezpieczeństwa

Lokalnie: `%APPDATA%/Godot/app_userdata/blackjack/profiles/<id>.json`.

Chmura używa **nazwy profilu**, np. `https://dsw-cloud.dsw-ppdg.workers.dev/v1/kv/51796/malykamis/save` albo `https://dsw-cloud.dsw-ppdg.workers.dev/v1/kv/51796/Ala/save`. Wielkość liter jest zachowana, a spacje i znaki specjalne są kodowane w URL. Na innym komputerze profil o tej samej nazwie korzysta z tego samego klucza chmury. Lokalne pliki nadal używają wewnętrznych identyfikatorów `user_...`, a lista profili pozostaje lokalna.

Migracja: metadane zapisują nazwę klucza jako `cloud.user_key`, ponieważ numer wersji jednego klucza nie może być użyty do zapisu pod innym. Po zmianie klucza wersja bazowa jest resetowana i dane pozostają niewysłane. Jeżeli pod nazwą nie ma zapisu i nie ma też lokalnego pliku, gra próbuje **wyłącznie odczytać** poprzedni zapis po starym ID. Odtwarza go lokalnie i czeka na kliknięcie Zapisz, aby utworzyć zapis pod nazwą. Stary zapis w chmurze pozostaje nietknięty. Konflikt pod nową nazwą wymaga wyboru wersji, więc nie zostaje po cichu nadpisany.

Po wyborze chmury w konflikcie poprzednie dane lokalne trafiają do `<id>.conflict-local.json`. Po czyszczeniu lokalnym kopia trafia do `<id>.cleared-backup.json`. Błędy sieci lub nieprawidłowe dane z API nie usuwają lokalnego postępu. Istniejące pliki z ćwiczenia 3 są rozpoznawane jako lokalne dane wymagające pierwszej synchronizacji.

## Wykonane sprawdzenia

- Debug: **84/84** sprawdzeń (69 zapis/synchronizacja + 15 odtworzenie po restarcie).
- Release: **84/84** takich samych sprawdzeń.
- Wszystkie testowe GET i POST synchronizacji trafiły do imitacji API związanej wyłącznie z `127.0.0.1`. Serwer w pamięci realizuje wzrost wersji i 409, a testy używają oddzielnych katalogów lokalnych.
- Sprawdzono pełną tabelę decyzji, brak wysyłki przy samym otwarciu/zamknięciu panelu, dokładnie jeden POST po kliknięciu Zapisz, brak dodatkowego potwierdzenia, brak zbędnych POST, kolejkę offline, oba rozwiązania konfliktu, zmianę wersji serwera pomiędzy odczytem a zapisem, zmiany w trakcie wysyłki, zmianę profilu w trakcie odczytu, izolację Ali i Olka, zapis profilu malykamis pod nazwą, odtwarzanie poprzedniego zapisu po ID bez automatycznej wysyłki oraz czyszczenie i odtwarzanie lokalnego zapisu w osobnym procesie.
- Wcześniejsze funkcje: profile **62/62** sprawdzeń w obu wersjach; sterowanie **50/50** w obu wersjach; zapis i ponowne wczytanie ustawień, w tym CRT - zaliczone.
- Końcowe logi testów nie zawierają błędów ani ostrzeżeń. Obejrzano panel zapisu, konflikt i menu po odtworzeniu danych.
- Rzeczywisty odczyt `GET /v1/kv/51796/ala/save` zwrócił **HTTP 200**, `ok=true`, `found=false`, `version=0`. Nie użyto POST ani DELETE. Adres samej przestrzeni `/v1/kv/51796` zwrócił 403; klient gry korzysta z pełnych ścieżek użytkownik/klucz, które działają.

Nie potwierdzono jeszcze zapisu i odczytu po rzeczywistym POST do usługi uczelnianej - ta próba wymaga odrębnej zgody użytkownika. Nie podłączono usług komercyjnych i dodatkowych slotów z rozszerzeń 8-9.

Dowody: `reports/cloud/*-checks.json`, `*-runtime.log`, `*-mock-requests.json`, `summary.json`, `real-profile-read-check.json`. Zrzuty: `reports/cloud/debug-cloud-*.png` i `release-cloud-*.png`.

## Powtórzenie testów lokalnych

```powershell
python tools/cloud_exercise.py all --godot "C:/sciezka/do/Godot.exe"
```

Gotowe eksporty można sprawdzić przez `python tools/cloud_exercise.py verify`. Skrypt uruchamia wyłącznie serwer localhost. Parametr transportu testowego w grze jest akceptowany tylko w trybie `--verify-cloud` i tylko dla `127.0.0.1`; test odmawia wysyłania swoich danych na adres internetowy.

Dostarczony `CloudSave.cs` jest klientem Unity, dlatego jego protokół przeniesiono do `Scripts/DswCloudClient.gd`. Logika synchronizacji i UI: `Scripts/RoamingSave.gd`. Testy: `Scripts/CloudVerification.gd` oraz `tools/cloud_exercise.py`.

## Propozycja jednorazowego testu rzeczywistej chmury

**OCZEKUJE NA ZATWIERDZENIE - NIE WYSŁANO.**

Jeden POST do `https://dsw-cloud.dsw-ppdg.workers.dev/v1/kv/51796/test_cw4/save`, z `expectedVersion=0`. Odrębny użytkownik techniczny `test_cw4` oddziela test od profili Ali i Olka. Dane mają **80 B**, całe ciało HTTP **124 B**. Zawartość: statystyki nowej gry, bez danych osobowych.

Dokładny adres, treść i limit jednej próby znajdują się w `reports/cloud/proposed-cloud-write.json`. Jeśli klucz już istnieje, 409 zakończy próbę bez ponowień i bez nadpisania. Nie zaplanowano usuwania danych w chmurze.
