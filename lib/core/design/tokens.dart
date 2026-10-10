import 'package:flutter/widgets.dart';

/// Дизайн-токены «Эй, Helpy» (стиль iOS, вариант A — «Чистый iOS»).
///
/// Единственное место, где в коде пишутся цвета, размеры шрифта, отступы,
/// скругления и тени. Экраны берут значения только отсюда и из компонентов
/// `lib/core/design/`. Описание — `docs/design/DESIGN.md`.
/// Контраст текста к своему фону — не ниже 4.5:1 (в скобках).
class AppColors {
  const AppColors._();

  // Поверхности
  /// Фон экранов.
  static const bg = Color(0xFFF2F4F3);

  /// Группы, карточки, шторки, поля.
  static const surface = Color(0xFFFFFFFF);

  /// Заливка поля поиска и дорожка сегмент-контрола.
  static const fill = Color(0xFFE4E8E6);

  /// Разделители и тонкие линии.
  static const separator = Color(0xFFE6EAE8);

  /// «Язычок» шторки.
  static const grabber = Color(0xFFC9D1CE);

  // Текст
  /// Основной текст (14.4:1 на fill).
  static const ink = Color(0xFF0F1A17);

  /// Вторичный текст: подписи, подзаголовки (5.3:1 на bg, 4.8:1 на fill).
  static const secondary = Color(0xFF5B6763);

  /// Третичный: шевроны, неактивное, подсказки в полях. Не для текста,
  /// который нужно прочитать.
  static const tertiary = Color(0xFFA3ADA9);

  // Бренд
  /// Акцент: главные кнопки, голосовая кнопка, выбранные чипы.
  static const accent = Color(0xFF2DB89A);

  /// Текст и значки на акценте (6.1:1).
  static const onAccent = Color(0xFF062B23);

  /// Акцентный текст, ссылки, значки (5.3:1 на белом, 4.8:1 на bg).
  static const accentText = Color(0xFF0B7A62);

  /// Тонированный фон акцента: TintedButton, квадраты значков (4.6:1).
  static const accentTint = Color(0xFFE2F4EF);

  /// Мятный бренда — подсветки.
  static const mint = Color(0xFFD8F0EA);

  /// Опасное действие: «Удалить», «Выйти», ошибки (6.6:1 на белом).
  static const danger = Color(0xFFB42318);

  /// Фон ошибок и опасных плашек.
  static const dangerTint = Color(0xFFFDE8E6);

  // Приоритет — точки (графика, не текст)
  static const priorityCritical = Color(0xFFE5484D);
  static const priorityHigh = Color(0xFFF59E0B);
  static const priorityNormal = Color(0xFFA3ADA9);

  // Плавающие панели (шапка, нижнее меню, панель действий)
  /// Полупрозрачный фон под размытием.
  static const bar = Color(0xDBF9FAFA); // rgba(249,250,250,.86)

  /// Неактивная вкладка нижнего меню (5.0:1 на фоне меню).
  static const tabInactive = Color(0xFF646F6B);

  /// Затемнение строки при нажатии.
  static const pressOverlay = Color(0x0F0F1A17);

  /// Затемнение фона под шторкой и диалогом.
  static const scrim = Color(0x660F1A17);

  /// Почти прозрачное затемнение под выпадающим окном (широкий экран).
  static const popoverScrim = Color(0x0F0F1A17);

  /// Цвет точки приоритета: critical — красная, high — оранжевая,
  /// остальные — серая.
  static Color priority(String p) => switch (p) {
        'critical' => priorityCritical,
        'high' => priorityHigh,
        _ => priorityNormal,
      };
}

/// Фон и текст плашки статуса заявки.
class StatusColors {
  const StatusColors(this.background, this.foreground);
  final Color background;
  final Color foreground;

  static const newOrder =
      StatusColors(Color(0xFFFFF4DE), Color(0xFF8A5A00)); // 5.4
  static const assigned =
      StatusColors(Color(0xFFE2F4EF), Color(0xFF0B7A62)); // 4.6
  static const inProgress =
      StatusColors(Color(0xFFE6F0FF), Color(0xFF1F5BB8)); // 5.6
  static const onReview =
      StatusColors(Color(0xFFEFE9FF), Color(0xFF5B3FB0)); // 6.4
  // Текст затемнён с #B45309 (4.54) до #A64B05 (5.2) — запас по контрасту.
  static const returned = StatusColors(Color(0xFFFFF1E6), Color(0xFFA64B05));
  static const done = StatusColors(Color(0xFFE3F5EE), Color(0xFF136B4F)); // 5.7
  static const cancelled =
      StatusColors(Color(0xFFEDEFEE), Color(0xFF5B6763)); // 5.1
  static const overdue =
      StatusColors(Color(0xFFFDE8E6), Color(0xFFB42318)); // 5.6

  /// Статус → цвета. Псевдостатусы: `overdue` (просрочена),
  /// `urgent` (срочная — как просроченная).
  static StatusColors of(String status) => switch (status) {
        'new' => newOrder,
        'assigned' => assigned,
        'in_progress' => inProgress,
        'on_review' => onReview,
        'returned' => returned,
        'done' => done,
        'overdue' || 'urgent' => overdue,
        _ => cancelled,
      };
}

/// Шрифт и шкала текста. Шрифт Onest (OFL), файлы — `assets/fonts`.
class AppText {
  const AppText._();

  static const family = 'Onest';

  /// Крупный заголовок экрана 34/41.
  static const largeTitle = TextStyle(
      fontFamily: family,
      fontSize: 34,
      height: 41 / 34,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      color: AppColors.ink);

  /// Заголовок карточки (заявки, объекта) 26/32.
  static const title = TextStyle(
      fontFamily: family,
      fontSize: 26,
      height: 32 / 26,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: AppColors.ink);

  /// Подзаголовок 20.
  static const title2 = TextStyle(
      fontFamily: family,
      fontSize: 20,
      height: 1.25,
      fontWeight: FontWeight.w600,
      color: AppColors.ink);

  /// Заголовок шапки, строки-заголовки, кнопки 17.
  static const headline = TextStyle(
      fontFamily: family,
      fontSize: 17,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: AppColors.ink);

  /// Основной текст 16.
  static const body = TextStyle(
      fontFamily: family,
      fontSize: 16,
      height: 1.35,
      fontWeight: FontWeight.w400,
      color: AppColors.ink);

  /// Заголовок строки списка 16 w500.
  static const rowTitle = TextStyle(
      fontFamily: family,
      fontSize: 16,
      height: 1.3,
      fontWeight: FontWeight.w500,
      color: AppColors.ink);

  /// Callout 15.
  static const callout = TextStyle(
      fontFamily: family,
      fontSize: 15,
      height: 1.35,
      fontWeight: FontWeight.w400,
      color: AppColors.ink);

  /// Подписи под строкой 13.
  static const footnote = TextStyle(
      fontFamily: family,
      fontSize: 13,
      height: 1.3,
      fontWeight: FontWeight.w400,
      color: AppColors.secondary);

  /// Мелкие подписи 12.
  static const caption = TextStyle(
      fontFamily: family,
      fontSize: 12,
      height: 1.3,
      fontWeight: FontWeight.w500,
      color: AppColors.secondary);

  /// Подписи нижнего меню 11.
  static const tabLabel = TextStyle(
      fontFamily: family,
      fontSize: 11,
      height: 1.2,
      fontWeight: FontWeight.w500);

  /// Заголовок секции 13 w600 ПРОПИСНЫЕ (сам текст переводится в
  /// прописные в [SectionHeader]).
  static const section = TextStyle(
      fontFamily: family,
      fontSize: 13,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
      color: AppColors.secondary);

  /// Число в плитке KPI 30 w700.
  static const kpi = TextStyle(
      fontFamily: family,
      fontSize: 30,
      height: 1.15,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      color: AppColors.ink);
}

/// Отступы.
class AppSpace {
  const AppSpace._();

  static const xxs = 2.0;
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Поля экрана слева и справа.
  static const screen = 16.0;

  /// Между группами.
  static const group = 12.0;

  /// Внутренние отступы строки списка.
  static const rowH = 16.0;
  static const rowV = 12.0;

  /// Минимальная высота строки списка.
  static const rowMinHeight = 46.0;

  /// Отступ разделителя строки, у которой есть значок 30 + 12.
  static const separatorInsetIcon = 16.0 + 30 + 12;

  /// Максимальная ширина списков и форм на широком экране (≥ [wideFrom]).
  static const contentMax = 720.0;

  /// С этой ширины окна — «широкий» экран.
  static const wideFrom = 900.0;
}

/// Скругления.
class AppRadius {
  const AppRadius._();

  /// Группы и карточки.
  static const group = 16.0;

  /// Кнопки и чипы — капсула.
  static const pill = 999.0;

  /// Дорожка сегмент-контрола и выбранный сегмент.
  static const segmentTrack = 10.0;
  static const segmentThumb = 8.0;

  /// Поле поиска и поля ввода.
  static const field = 12.0;

  /// Верхние углы шторки.
  static const sheet = 14.0;

  /// Квадрат значка в строке.
  static const iconTile = 8.0;
}

/// Тени — только у плавающих элементов.
class AppShadows {
  const AppShadows._();

  /// Выбранный сегмент.
  static const segment = [
    BoxShadow(color: Color(0x1F0F1A17), blurRadius: 3, offset: Offset(0, 1)),
  ];

  /// Голосовая кнопка (акцентная тень).
  static const voice = [
    BoxShadow(color: Color(0x662DB89A), blurRadius: 18, offset: Offset(0, 6)),
  ];

  /// Плавающие кнопки и карточки поверх карты, всплывающие сообщения.
  static const floating = [
    BoxShadow(color: Color(0x1F0F1A17), blurRadius: 16, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x0F0F1A17), blurRadius: 2, offset: Offset(0, 1)),
  ];
}

/// Размеры элементов.
class AppSizes {
  const AppSizes._();

  static const iconS = 18.0;
  static const icon = 22.0;
  static const iconL = 24.0;

  /// Квадрат значка в строке.
  static const iconTile = 30.0;

  /// Главная кнопка.
  static const buttonHeight = 52.0;

  /// Маленькая кнопка-капсула (TintedButton в строке).
  static const buttonSmallHeight = 32.0;

  static const searchHeight = 38.0;
  static const segmentHeight = 34.0;
  static const pillHeight = 24.0;

  /// «Таблетка» фильтра над списком (видимая капсула; цель нажатия —
  /// [minTap]).
  static const filterChip = 34.0;

  /// Наименьшая цель нажатия (рекомендация iOS / Android).
  static const minTap = 44.0;

  /// Боковая панель на широком экране («Фильтры»).
  static const sidePanel = 400.0;

  /// Голосовая кнопка.
  static const voiceHeight = 56.0;

  /// Высота шапки (строка с кнопками) и крупного заголовка.
  static const navBar = 44.0;
  static const largeTitle = 52.0;

  /// Нижнее меню вкладок (без системного отступа).
  static const tabBar = 56.0;

  /// Сколько оставить под последним элементом списка, над которым
  /// плавает голосовая кнопка.
  static const fabClearance = voiceHeight + 32;
}

/// Длительности анимаций.
class AppMotion {
  const AppMotion._();
  static const fast = Duration(milliseconds: 120);
  static const normal = Duration(milliseconds: 220);
}
