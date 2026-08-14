# Hey Helpy 🦀

AI-помощник для эксплуатации объектов недвижимости — заявки и контроль работ в одно касание. Mobile (iOS/Android) + Web из единой кодовой базы (Flutter), бэкенд — Supabase.

> Это **Фаза 0 (каркас)**: аутентификация, ролевая навигация, главный экран с «одной кнопкой» и заготовки экранов. Полное ТЗ — в `../tech-spec.md`.

## Стек

- **Flutter** (Dart) — web + iOS + Android.
- **Supabase** — Postgres, Auth, Realtime, Storage.
- `go_router` — навигация с редиректом по сессии.

## Что уже есть

- Экран входа/регистрации (email + пароль).
- Автосоздание профиля пользователя при регистрации (триггер в БД).
- Редирект неавторизованных на `/login`, авторизованных — на главный.
- Главный экран: большая кнопка **«Создать заявку»** + подсказка про голосовую активацию «Эй Хелпи».
- Ролевые действия в AppBar (Отчёты — для менеджера/админа, Администрирование — для админа).
- Заготовки экранов: создание заявки (текст/голос/камера), отчёты, администрирование.
- SQL-миграции с моделью данных и базовым RLS (company-scope).

## Предварительные требования

- **Flutter SDK 3.24+** (`flutter --version`).
- Аккаунт **Supabase** и созданный проект.

## Настройка

### 1. Сгенерировать платформенные папки

В репозитории лежит только `lib/`, `pubspec.yaml` и миграции. Платформенные обвязки (`android/`, `ios/`, `web/`) сгенерируй один раз, не затирая `lib/`:

```bash
cd hey_helpy
flutter create . --project-name hey_helpy --platforms=web,android,ios
flutter pub get
```

### 2. Поднять базу в Supabase

Создай проект на https://supabase.com. Затем примени миграции **по порядку** — через SQL Editor (скопируй содержимое файлов) или через Supabase CLI:

```bash
# вариант с CLI (если установлен supabase)
supabase db execute --file supabase/migrations/0001_init.sql
supabase db execute --file supabase/migrations/0002_domain.sql
```

Иначе просто выполни содержимое `0001_init.sql`, затем `0002_domain.sql` в SQL Editor.

### 3. Взять ключи

В Supabase → Project Settings → API возьми **Project URL** и **anon public key**.

## Запуск

Ключи передаются через `--dart-define` и **не коммитятся** в код:

```bash
# Web
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://<your>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>

# Android / iOS — то же, но -d <device>
```

Чтобы не вводить ключи каждый раз, можно завести файл `env.json` (он в `.gitignore`):

```json
{ "SUPABASE_URL": "https://<your>.supabase.co", "SUPABASE_ANON_KEY": "<anon-key>" }
```

и запускать: `flutter run --dart-define-from-file=env.json`.

> Если ключи не переданы — приложение покажет экран-подсказку по настройке (не упадёт).

## Первый вход

1. Зарегистрируйся на экране входа (email + пароль). В БД создастся профиль с ролью `requester`.
2. Чтобы получить роль `admin`/`manager` и привязку к компании, обнови строку в таблице `profiles` (например, через Supabase Table Editor): создай запись в `companies`, проставь `company_id` и нужный `role` своему профилю.

## Структура

```
hey_helpy/
├─ lib/
│  ├─ main.dart                 # инициализация Supabase
│  ├─ app.dart                  # MaterialApp.router + тема
│  ├─ core/
│  │  ├─ supabase_config.dart   # ключи из --dart-define
│  │  ├─ theme.dart
│  │  └─ router.dart            # go_router + редирект по auth
│  ├─ models/                   # profile.dart, user_role.dart
│  └─ features/
│     ├─ auth/                  # репозиторий + экран логина
│     ├─ home/                  # главный экран «одна кнопка»
│     ├─ requests/              # создание заявки (заготовка)
│     ├─ reports/               # отчёты (заготовка)
│     └─ admin/                 # администрирование (заготовка)
└─ supabase/migrations/         # 0001_init.sql, 0002_domain.sql
```

## Дальше (Фаза 1)

Наполнить создание заявки (разовые/регулярные + чек-лист + фотоподтверждение), жизненный цикл заявки с realtime, справочники в администрировании и web-отчёты с фильтрами.
