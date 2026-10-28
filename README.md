# ForgeFit — aplikacja treningowa z prawdziwym kontem i bazą danych

ForgeFit to aplikacja React/Vite połączona z Supabase. Nie ma trybu demo ani przykładowych treningów/rekordów. Nowe konto zaczyna z zerową objętością, zerową liczbą treningów i serii oraz masą ciała ustawioną na 0 kg do samodzielnego uzupełnienia. Biblioteka podstawowych ćwiczeń jest dodawana automatycznie, ale nie ma w niej fikcyjnych wyników.

## Funkcje

- Rejestracja i logowanie e-mail + hasło przez Supabase Auth.
- Treningi, ćwiczenia, serie, RIR/RPE, przerwy i profil trwale zapisywane w Supabase.
- Szacowany 1RM, rekordy, raport objętości i rozkład grup mięśniowych.
- Progresja z przyrostem ustawianym dla całej sztangi albo na każdą stronę.
- Powiadomienia w aplikacji o rekordach i możliwej progresji.
- Ranking siły względnej jako procent masy ciała oraz ranking znajomych w prywatnych grupach.
- Grupy treningowe z kodem zaproszenia. Udostępniaj kod tylko osobom, które mają być w grupie.
- Responsywny, ciemny interfejs mobilny i desktopowy.

## Wymagania

- Node.js 20 lub nowszy
- Projekt Supabase
- Konto Netlify do hostingu (opcjonalnie; lokalnie działa po konfiguracji Supabase)

## Uruchomienie backendu — wymagane

Aplikacja nie może zapisywać danych online, dopóki nie podłączysz własnego projektu Supabase. Nie umieszczaj klucza `service_role` w aplikacji.

1. Utwórz projekt w [Supabase](https://supabase.com/).
2. Otwórz **SQL Editor** i uruchom cały plik `supabase/schema.sql`.
3. W **Authentication → URL Configuration** ustaw adres aplikacji. Przy lokalnym uruchomieniu dodaj `http://localhost:5173` do Redirect URLs. Po wdrożeniu dodaj również adres Netlify.
4. Skopiuj `.env.example` do pliku `.env.local` i wpisz dane z **Project Settings → API**:

   ```env
   VITE_SUPABASE_URL=https://TWÓJ_PROJEKT.supabase.co
   VITE_SUPABASE_ANON_KEY=TWÓJ_KLUCZ_PUBLISHABLE_LUB_ANON
   ```

5. Zainstaluj zależności i uruchom aplikację:

   ```bash
   npm install
   npm run dev
   ```

6. Otwórz adres podany przez Vite, załóż konto i potwierdź e-mail, jeśli Supabase wymaga potwierdzenia.

## Wdrożenie na Netlify

1. Wypchnij pliki do repozytorium GitHub.
2. W Netlify wybierz **Add new site → Import an existing project** i wybierz repozytorium.
3. Ustaw build command `npm run build` i katalog publikacji `dist`.
4. W **Site configuration → Environment variables** dodaj `VITE_SUPABASE_URL` i `VITE_SUPABASE_ANON_KEY`.
5. Uruchom deploy.
6. Dodaj domenę Netlify w Supabase **Authentication → URL Configuration** i jako redirect URL.

## Dane i prywatność

- Treningi i ćwiczenia są przypisane do `auth.uid()` i chronione przez Row Level Security.
- Każdy użytkownik ma własny profil i prywatną historię.
- Ranking grupowy pokazuje dane tylko członkom wspólnej grupy; dołączenie wymaga kodu zaproszenia.
- Masa ciała zaczyna się od 0, dlatego procent masy ciała nie będzie liczony, dopóki użytkownik nie uzupełni profilu.
- Powiadomienia są wewnątrz aplikacji. Powiadomienia push, gdy aplikacja jest zamknięta, nie są w tej wersji skonfigurowane.

## Wzory i zasady

- Szacowany 1RM: `ciężar × (1 + powtórzenia / 30)` — to estymacja, a nie rzeczywisty test maksymalny.
- Przyrost `total` dodaje wartość do całego ciężaru; `side` dodaje ją na każdą stronę, czyli łącznie podwaja przyrost.
- Ranking względny: szacowany 1RM / masa ciała × 100.
- Sugestie progresji są wskazówką, nie automatycznym zaleceniem. Zwiększaj ciężar tylko wtedy, gdy potrafisz wykonać ćwiczenie poprawnie.
