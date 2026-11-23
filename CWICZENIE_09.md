# Ćwiczenie 9 — lokalizacja Blackjacka

Język można zmienić przy wyborze profilu albo w **Ustawienia → Język**. Polski jest ustawieniem początkowym. Zmiana działa od razu i jest zapamiętywana w ustawieniach na danym urządzeniu.

Teksty interfejsu, rozgrywki, osiągnięć, talizmanów, licencji i zapisu w chmurze znajdują się w katalogach [Locale/pl.po](Locale/pl.po) oraz [Locale/en.po](Locale/en.po). Katalogi zawierają pełne komunikaty z parametrami i reguły liczby mnogiej dla liczby rozegranych rund. Format liczb i dat w interfejsie zależy od języka. Nazwy profili i identyfikatory danych zachowują wartości zapisane przez gracza.

## Sprawdzenie

- python tools/check_localization.py porównuje klucze projektu z oboma katalogami i sprawdza parametry. Ta kontrola działa też przed eksportem uruchamianym przez narzędzia projektu.
- python tools/localization_exercise.py sprawdza kompilację Windows debug na odizolowanym profilu. Test przełącza język, uruchamia grę ponownie i zapisuje zrzuty ekranów w reports.
- W przeglądzie układu można też uruchomić Windows debug z argumentami -- --pseudo-locale. Godot wydłuża teksty i dodaje znaki diakrytyczne.

[Dokumentacja gettext w Godocie 4.5](https://docs.godotengine.org/en/4.5/tutorials/i18n/localization_using_gettext.html)
