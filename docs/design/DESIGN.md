# Дизайн-система «Эй, Helpy» — вариант A «Чистый iOS»

Код — `lib/core/design/` (один импорт: `import '.../core/design/design.dart';`).
Тесты компонентов — `test/design_test.dart`.

## Главное правило

**В экранах — только токены и компоненты.** Нельзя писать в экране `Color(0x…)`,
`TextStyle(fontSize: …)`, числа отступов «на глаз», `Icons.*`, `InkWell`, `Card`,
`AlertDialog`, `showModalBottomSheet`, `MaterialPageRoute`. Если чего-то не хватает,
сначала добавляем токен или компонент в `lib/core/design/` (с тестом), потом
используем его в экране. Новые экраны (план этажей в шаге 14 и дальше) собираются
только из этих компонентов.

## Токены (`tokens.dart`)

### Цвета — `AppColors`

| Токен | Цвет | Где |
|---|---|---|
| `bg` | `#F2F4F3` | фон экранов, шторок |
| `surface` | `#FFFFFF` | группы, карточки, поля ввода |
| `fill` | `#E4E8E6` | поле поиска, дорожка сегмент-контрола, вторичные кнопки |
| `separator` | `#E6EAE8` | разделители (0.5 px) |
| `ink` | `#0F1A17` | основной текст |
| `secondary` | `#5B6763` | подписи, подзаголовки (5.3:1 на `bg`) |
| `tertiary` | `#A3ADA9` | шевроны, неактивное (не для текста, который нужно прочитать) |
| `accent` | `#2DB89A` | главные кнопки, голосовая кнопка, выбранные чипы |
| `onAccent` | `#062B23` | текст на акценте (6.1:1) |
| `accentText` | `#0B7A62` | ссылки, акцентный текст и значки (5.3:1 на белом) |
| `accentTint` | `#E2F4EF` | TintedButton, квадраты значков |
| `mint` | `#D8F0EA` | подсветки (выделение текста, выбранная строка) |
| `danger` / `dangerTint` | `#B42318` / `#FDE8E6` | удалить, выйти, ошибки |
| `priorityCritical` / `High` / `Normal` | `#E5484D` / `#F59E0B` / `#A3ADA9` | точки приоритета |
| `bar` | `rgba(249,250,250,.86)` | шапка, нижнее меню, панель действий (под размытием 20) |
| `tabInactive` | `#646F6B` | неактивная вкладка (5.0:1; в задании `#6B7672` — 4.5:1, затемнён для запаса) |

### Статусы — `StatusColors.of(status)`

| Статус | Фон | Текст | Контраст |
|---|---|---|---|
| Новая `new` | `#FFF4DE` | `#8A5A00` | 5.4 |
| Назначена `assigned` | `#E2F4EF` | `#0B7A62` | 4.6 |
| В работе `in_progress` | `#E6F0FF` | `#1F5BB8` | 5.6 |
| На проверке `on_review` | `#EFE9FF` | `#5B3FB0` | 6.4 |
| Возвращена `returned` | `#FFF1E6` | `#A64B05` | 5.2 (в задании `#B45309` — 4.54, затемнён) |
| Принята `done` | `#E3F5EE` | `#136B4F` + галочка | 5.7 |
| Отменена `cancelled` | `#EDEFEE` | `#5B6763` | 5.1 |
| Просрочена `overdue` | `#FDE8E6` | `#B42318` | 5.6 |

Контраст всех пар проверяет тест «Токены» в `test/design_test.dart`.

### Шрифт — `AppText`

Onest (SIL OFL 1.1), файлы `assets/fonts/Onest-{Regular,Medium,SemiBold,Bold}.ttf`
(400/500/600/700, сделаны из вариативного шрифта Google Fonts), из сети не грузится.

| Стиль | Размер / высота | Вес | Где |
|---|---|---|---|
| `largeTitle` | 34/41, −0.4 | 700 | крупный заголовок экрана |
| `title` | 26/32 | 700 | заголовок карточки заявки, объекта |
| `title2` | 20 | 600 | подзаголовок |
| `headline` | 17 | 600 | шапка, кнопки, заголовок шторки |
| `body` / `rowTitle` | 16 | 400 / 500 | текст, заголовок строки |
| `callout` | 15 | 400 | сообщения, чипы |
| `footnote` | 13 | 400 | подписи под строкой |
| `caption` | 12 | 500 | мелкие подписи, капсулы |
| `tabLabel` | 11 | 500/600 | нижнее меню |
| `section` | 13, +0.4, ПРОПИСНЫЕ | 600 | заголовок секции |
| `kpi` | 30 | 700 | число в плитке KPI |

### Отступы, радиусы, тени, размеры

- `AppSpace`: края экрана 16, между группами 12, строка 12×16 и высота ≥ 46;
  на ширине ≥ 900 (`wideFrom`) списки и формы — по центру до 720 (`contentMax`),
  карта и отчёты — во всю ширину.
- `AppRadius`: группы и карточки 16, кнопки и чипы — капсула, сегмент-контрол 10/8,
  поле поиска и поля ввода 12, шторка 14, квадрат значка 8.
- `AppShadows`: только у плавающих элементов — выбранный сегмент
  (`0 1 3 rgba(15,26,23,.12)`), голосовая кнопка (`rgba(45,184,154,.40)`),
  кнопки и карточки поверх карты, всплывающие сообщения. У групп и карточек —
  без теней и без рамок.
- `AppSizes`: кнопка 52, маленькая кнопка 32, поиск 38, сегмент 34, таблетка фильтра 34, капсула статуса 24,
  голосовая кнопка 56, шапка 44 + крупный заголовок 52, нижнее меню 56, боковая панель 400 (`sidePanel`).
  **Цель нажатия — не меньше 44 px (`minTap`)**: видимая капсула может быть меньше
  (таблетка 34, значок ⓘ 18), но нажимается полоса 44.

### Значки — `AppIcons`

Один набор: **Lucide** (ISC), вес 300 (штрих 1.55), размер 18–24. Активная вкладка
нижнего меню — тот же значок со штрихом 2 (`AppIcons.homeActive` и т. п.): у Lucide
нет залитых значков. Новый значок — добавить в `icons.dart` (имя с lucide.dev, суффикс 300).

## Тема (`app_theme.dart`)

`AppTheme.light()` — единственная `ThemeData`: шрифт Onest, фон `bg`, без «волн»
(`NoSplash`), переходы `CupertinoPageTransitionsBuilder` на всех платформах,
поля ввода белые r12 без рамки (в фокусе — акцентная 1.5), календарь, переключатели,
меню и подсказки — в цветах токенов.

## Компоненты

| Компонент | Файл | Что это |
|---|---|---|
| `Pressable` | pressable.dart | нажимаемая область без волны: масштаб 0.97 (кнопки) или затемнение (строки); клавиатура, роль «кнопка» |
| `AppGroup`, `AppRow`, `AppSeparator`, `AppCard` | group.dart | сгруппированный список как в Настройках iOS; строка: ведущий элемент, заголовок + подзаголовок, значение/трейлинг, шеврон |
| `SectionHeader` | group.dart | подпись секции ПРОПИСНЫМИ |
| `LeadingIcon`, `InitialsTile`, `PriorityDot`, `ChevronEnd` | group.dart | значок в квадрате 30×30 r8, инициалы, точка приоритета, стрелка «дальше» (RTL) |
| `StatusPill`, `PriorityPill` | controls.dart | капсула 24 с точкой (у «Принята» — галочка) |
| `SegmentedControl` | controls.dart | сегмент-контрол iOS |
| `AppSearchField` | controls.dart | поле поиска 38 с лупой и крестиком |
| `AppChip`, `FilterTag` | controls.dart | чип-выбор (выбранный — акцент с галочкой), плашка фильтра с крестиком |
| `AppFilterChip` | filters.dart | «таблетка» фильтра над списком (капсула 34, цель нажатия 44): обычная — белая с подписью и стрелкой вниз; активная — `accentTint`, краткая подпись выбора (`accentText` w600) и ✕; `strong` — акцентная заливка (кнопка «Фильтры · 3» при активных фильтрах), `chevron: false` — без стрелки, `compact` — только значок. Не `FilterChip` — чтобы не путать с Material |
| `AppFadingScroll` | filters.dart | горизонтальная прокрутка, гаснущая у края, за которым есть ещё (строки таблеток) |
| `showAppSidePanel` | filters.dart | длинное окно (все фильтры): на телефоне — шторка на весь экран, на ПК — панель справа 400 px на всю высоту, выезжает сбоку |
| `AppInfoButton`, `showAppInfo` | info.dart | маленькая ⓘ (цель 44) → короткая подсказка в шторке: заголовок, 2–4 строки с точкой, «Понятно». Подсказки: фильтры, этажи, загрузка плана, маркеры плана, режим расстановки |
| `AppCheckRow` | filters.dart | строка выбора с галочкой справа (множественный и одиночный выбор); вместо текста можно передать `child` (например `StatusPill`) |
| `AppFilterPanel`, `AppPanelGroup` | filters.dart | содержимое окна фильтра: заголовок, шапка (сегмент-контрол), поиск по списку, прокручиваемые строки, «Сбросить» / «Применить (N)» |
| `showFilterPicker`, `showAppPopover` | filters.dart | окно выбора: на узком экране — `showAppSheet`, на широком (≥ 900) — выпадающее окно под таблеткой (фон `bg`, r16, тень `floating`, закрывается нажатием мимо) |
| `AppButton` (`.primary/.tinted/.secondary/.destructive/.plain`), `AppIconButton`, `CountBadge` | buttons.dart | кнопки-капсулы, круглая кнопка-значок, красный кружок с числом |
| `AppSliverHeader`, `AppNavBar`, `AppBackButton`, `AppBarTextButton` | nav_bar.dart | шапка с крупным заголовком (сжимается при прокрутке, размытие 20, линия при прокрутке), компактная шапка, «‹ Предыдущий экран» |
| `AppSliverBar` | nav_bar.dart | полоса под шапкой: закреплённая (поиск и фильтры остаются сверху при прокрутке) или `floating` (сегменты прячутся при прокрутке вниз и возвращаются вверх) |
| `AppScaffold`, `SliverContent`, `ContentWidth`, `SliverBottomInset`, `appRoute` | nav_bar.dart | каркас экрана, колонка до 720, отступ под меню, маршрут iOS с подписью «назад» |
| `AppTabBar` | surfaces.dart | нижнее меню: полупрозрачное с размытием |
| `VoiceButton` | surfaces.dart | капсула «Эй, Helpy» с микрофоном + белая круглая «+» |
| `BottomActionBar` | surfaces.dart | панель главной кнопки внизу экрана (размытие, линия) |
| `showAppSheet`, `SheetHeader`, `SheetGrabber` | surfaces.dart | нижняя шторка: углы 14, язычок 36×5, «Отмена · Заголовок · Готово» |
| `showAppDialog` | surfaces.dart | диалог подтверждения: белая карточка r16, кнопки-капсулы |
| `KpiTile`, `AppLoader`, `AppEmptyState` | surfaces.dart | плитка показателя, крутилка, пустое состояние / ошибка |
| `showAppMessage` | ../app_message.dart | всплывающее сообщение сверху (белая карточка r16 с тенью); `actionLabel` + `onAction` — кнопка в сообщении («Сохранено · Отменить», висит 5 с) |
| `PlanCanvas`, `PlanMarker`, `PlanThumb` | features/floors/ | холст плана этажа (масштаб жестами, колесом и кнопками `MapControlButton`; маркеры одного размера при любом масштабе: помещение — кружок с числом открытых заявок, оборудование — квадрат со значком, цвет — как у маркера карты), превью плана 52×36 в строке этажа |
| `HomeHeader`, `HomeTopBar` | features/home/home_chrome.dart | шапка вкладок главного экрана (колокольчик, «Заявки · Подрядчики · Локации») |

## Примеры

Экран со списком:

```dart
AppScaffold(
  title: l.profileNotifications,
  onRefresh: _load,
  slivers: [
    SliverContent(sliver: SliverList.list(children: [
      AppGroup(header: l.sectionToday, children: [
        AppRow(
          leading: const PriorityDot('high'),
          title: order.title,
          subtitle: '$room · $workType',
          trailing: StatusPill(order.status),
          onTap: () => open(order),
        ),
      ]),
    ])),
  ],
);
```

Шторка с формой:

```dart
showAppSheet<bool>(
  context: context,
  builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
    SheetHeader(title: l.formTitle, doneLabel: l.commonSave, onDone: _save),
    Padding(
      padding: const EdgeInsetsDirectional.all(AppSpace.screen),
      child: AppGroup(children: [TextField(...)]),
    ),
  ]),
);
```

Главная кнопка экрана: `AppScaffold(bottomBar: BottomActionBar(child: AppButton.primary(label: …, onPressed: …)))`.

## Вёрстка справа налево

Только `EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`;
стрелки — `ChevronEnd` и `AppBackButton` (сами разворачиваются).
