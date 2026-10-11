import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/core/design/design.dart';
import 'package:hey_helpy/l10n/app_localizations.dart';

/// Обёртка с темой и переводами (русский).
Widget _app(Widget child, {Size size = const Size(412, 900)}) => MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: child),
      ),
    );

/// Относительная яркость цвета (WCAG 2.x).
double _lum(Color c) {
  double lin(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}

double _contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

void main() {
  group('Токены', () {
    test('текст статусов — контраст не ниже 4.5:1 к своему фону', () {
      for (final s in const [
        'new',
        'assigned',
        'in_progress',
        'on_review',
        'returned',
        'done',
        'cancelled',
        'overdue',
      ]) {
        final c = StatusColors.of(s);
        expect(_contrast(c.background, c.foreground), greaterThanOrEqualTo(4.5),
            reason: s);
      }
    });

    test('основные пары текста и фона — не ниже 4.5:1', () {
      final pairs = [
        (AppColors.onAccent, AppColors.accent),
        (AppColors.accentText, AppColors.surface),
        (AppColors.accentText, AppColors.bg),
        (AppColors.accentText, AppColors.accentTint),
        (AppColors.secondary, AppColors.bg),
        (AppColors.secondary, AppColors.fill),
        (AppColors.ink, AppColors.fill),
        (AppColors.danger, AppColors.surface),
        (AppColors.danger, AppColors.fill),
        (AppColors.tabInactive, const Color(0xFFF9FAFA)),
      ];
      for (final (fg, bg) in pairs) {
        expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5),
            reason: '$fg на $bg');
      }
    });

    test('точка приоритета: critical, high, остальные', () {
      expect(AppColors.priority('critical'), AppColors.priorityCritical);
      expect(AppColors.priority('high'), AppColors.priorityHigh);
      expect(AppColors.priority('low'), AppColors.priorityNormal);
    });
  });

  testWidgets('AppGroup и AppRow: строки, разделитель, нажатие', (t) async {
    var taps = 0;
    await t.pumpWidget(_app(AppGroup(header: 'Поля', children: [
      AppRow(
          leading: const LeadingIcon(AppIcons.building),
          title: 'Объект',
          value: 'БЦ',
          onTap: () => taps++),
      const AppRow(title: 'Помещение', subtitle: '2 этаж'),
    ])));
    expect(find.text('ПОЛЯ'), findsOneWidget);
    expect(find.text('Объект'), findsOneWidget);
    expect(find.text('2 этаж'), findsOneWidget);
    expect(find.byType(AppSeparator), findsOneWidget);
    expect(find.byType(ChevronEnd), findsOneWidget);
    await t.tap(find.text('Объект'));
    expect(taps, 1);
    // Без «волны» Material.
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('AppRow на 360: длинное значение не сжимает заголовок (шаг 18)',
      (t) async {
    await t.pumpWidget(_app(const Center(
      child: SizedBox(
        width: 328,
        child: AppRow(
            leading: LeadingIcon(AppIcons.map),
            title: 'Адрес',
            value: 'Белград, Савски венац, улица очень длинная (демо)'),
      ),
    )));
    final title = t.getSize(find.text('Адрес'));
    // Заголовок в одну строку (высота строки текста), а не «Адре / с».
    expect(title.height, lessThan(30));
  });

  testWidgets('SectionHeader — прописными', (t) async {
    await t.pumpWidget(_app(const SectionHeader('Описание')));
    expect(find.text('ОПИСАНИЕ'), findsOneWidget);
  });

  testWidgets('StatusPill: подпись по статусу, у «Принята» — галочка',
      (t) async {
    await t.pumpWidget(_app(const Column(children: [
      StatusPill('new'),
      StatusPill('done'),
    ])));
    expect(find.text('Новая'), findsOneWidget);
    expect(find.byIcon(AppIcons.check), findsOneWidget);
    final box = t.getSize(find.byType(StatusPill).first);
    expect(box.height, AppSizes.pillHeight);
  });

  testWidgets('SegmentedControl: выбор сегмента', (t) async {
    var value = 0;
    await t.pumpWidget(_app(StatefulBuilder(
      builder: (context, set) => SegmentedControl<int>(
        segments: const [Segment(0, 'Список'), Segment(1, 'Карта')],
        selected: value,
        onChanged: (v) => set(() => value = v),
      ),
    )));
    await t.tap(find.text('Карта'));
    await t.pumpAndSettle();
    expect(value, 1);
  });

  testWidgets('AppSearchField: ввод и очистка', (t) async {
    var text = '';
    await t.pumpWidget(_app(AppSearchField(
      hint: 'Поиск',
      onChanged: (v) => text = v,
    )));
    expect(find.byIcon(AppIcons.search), findsOneWidget);
    await t.enterText(find.byType(TextField), 'кондиционер');
    await t.pump();
    expect(text, 'кондиционер');
    await t.tap(find.byIcon(AppIcons.close));
    await t.pump();
    expect(text, '');
    expect(
        t.getSize(find.byType(AppSearchField)).height, AppSizes.searchHeight);
  });

  testWidgets('Кнопки: виды, неактивная, нажатие с масштабом', (t) async {
    var taps = 0;
    await t.pumpWidget(_app(Column(children: [
      AppButton.primary(label: 'Отправить', onPressed: () => taps++),
      AppButton.tinted(label: 'Сменить', onPressed: () {}, small: true),
      const AppButton.secondary(label: 'Позже', onPressed: null),
      AppButton.destructive(label: 'Удалить', onPressed: () {}),
      AppIconButton(
          icon: AppIcons.bell,
          label: 'Уведомления',
          badge: 3,
          onPressed: () {}),
    ])));
    final gesture = await t.startGesture(t.getCenter(find.text('Отправить')));
    await t.pump(const Duration(milliseconds: 200));
    final scale =
        t.widgetList<AnimatedScale>(find.byType(AnimatedScale)).first.scale;
    expect(scale, 0.97);
    await gesture.up();
    await t.pumpAndSettle();
    expect(taps, 1);
    expect(
        t.getSize(find.byType(AppButton).first).height, AppSizes.buttonHeight);
    expect(find.text('3'), findsOneWidget);
    // Неактивная — не нажимается.
    await t.tap(find.text('Позже'));
    expect(taps, 1);
  });

  testWidgets('AppSliverHeader: крупный заголовок сжимается при прокрутке',
      (t) async {
    await t.pumpWidget(_app(CustomScrollView(slivers: [
      const AppSliverHeader(title: 'Заявки', showBack: false),
      SliverList.list(children: [
        for (var i = 0; i < 40; i++) SizedBox(height: 60, child: Text('$i')),
      ]),
    ])));
    // Крупный и маленький (пока прозрачный) заголовки.
    expect(find.text('Заявки'), findsNWidgets(2));
    final large = t.widget<Text>(find.text('Заявки').last);
    expect(large.style?.fontSize, 34);
    await t.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await t.pumpAndSettle();
    final opacities = t
        .widgetList<Opacity>(find.ancestor(
            of: find.text('Заявки').first, matching: find.byType(Opacity)))
        .map((o) => o.opacity);
    expect(opacities.first, 1);
  });

  testWidgets('appRoute: кнопка «назад» подписана экраном, откуда пришли',
      (t) async {
    await t.pumpWidget(_app(Builder(
      builder: (context) => AppButton(
        label: 'Открыть',
        onPressed: () => Navigator.push(
            context,
            appRoute((_) => const AppScaffold(title: 'Заявка', slivers: []),
                title: 'Заявки')),
      ),
    )));
    await t.tap(find.text('Открыть'));
    await t.pumpAndSettle();
    expect(find.text('Заявки'), findsOneWidget);
    await t.tap(find.text('Заявки'));
    await t.pumpAndSettle();
    expect(find.text('Открыть'), findsOneWidget);
  });

  testWidgets('AppTabBar: вкладки, активная, переключение', (t) async {
    var index = 0;
    await t.pumpWidget(_app(StatefulBuilder(
      builder: (context, set) => Align(
        alignment: Alignment.bottomCenter,
        child: AppTabBar(
          index: index,
          onChanged: (i) => set(() => index = i),
          tabs: const [
            AppTab(
                icon: AppIcons.home,
                activeIcon: AppIcons.homeActive,
                label: 'Главная'),
            AppTab(
                icon: AppIcons.profile,
                activeIcon: AppIcons.profileActive,
                label: 'Профиль'),
          ],
        ),
      ),
    )));
    expect(find.byIcon(AppIcons.homeActive), findsOneWidget);
    await t.tap(find.text('Профиль'));
    await t.pump();
    expect(index, 1);
    expect(find.byIcon(AppIcons.profileActive), findsOneWidget);
  });

  testWidgets('VoiceButton: капсула с микрофоном и «+»', (t) async {
    var voice = 0, add = 0;
    await t.pumpWidget(_app(Center(
      child: VoiceButton(
        label: 'Эй, Helpy',
        semanticLabel: 'Нажми и говори',
        onVoice: () => voice++,
        addLabel: 'Создать заявку',
        onAdd: () => add++,
      ),
    )));
    expect(find.byIcon(AppIcons.mic), findsOneWidget);
    await t.tap(find.text('Эй, Helpy'));
    await t.tap(find.byIcon(AppIcons.add));
    expect((voice, add), (1, 1));
    expect(find.bySemanticsLabel(RegExp('Нажми и говори')), findsOneWidget);
  });

  testWidgets('Шторка: язычок и шапка «Отмена · Заголовок · Готово»',
      (t) async {
    var done = 0;
    await t.pumpWidget(_app(Builder(
      builder: (context) => AppButton(
        label: 'Открыть',
        onPressed: () => showAppSheet<void>(
          context: context,
          builder: (_) => SheetHeader(
              title: 'Новая заявка', doneLabel: 'Готово', onDone: () => done++),
        ),
      ),
    )));
    await t.tap(find.text('Открыть'));
    await t.pumpAndSettle();
    expect(find.byType(SheetGrabber), findsOneWidget);
    expect(find.text('Новая заявка'), findsOneWidget);
    expect(find.text('Отмена'), findsOneWidget);
    await t.tap(find.text('Готово'));
    expect(done, 1);
    await t.tap(find.text('Отмена'));
    await t.pumpAndSettle();
    expect(find.text('Новая заявка'), findsNothing);
  });

  testWidgets('BottomActionBar и KpiTile отрисовываются', (t) async {
    await t.pumpWidget(_app(Column(children: [
      const Expanded(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: KpiTile(value: '87%', label: 'В срок'),
        ),
      ),
      BottomActionBar(
          child: AppButton.primary(label: 'Принять', onPressed: () {})),
    ])));
    expect(find.text('87%'), findsOneWidget);
    expect(t.widget<Text>(find.text('87%')).style?.fontSize, 30);
    expect(find.text('Принять'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('showAppDialog возвращает выбранное действие', (t) async {
    bool? result;
    await t.pumpWidget(_app(Builder(
      builder: (context) => AppButton(
        label: 'Удалить заявку',
        onPressed: () async {
          result = await showAppDialog<bool>(
              context: context,
              title: 'Удалить?',
              message: 'Действие нельзя отменить',
              actions: const [
                AppDialogAction('Удалить', true, destructive: true),
                AppDialogAction('Отмена', false),
              ]);
        },
      ),
    )));
    await t.tap(find.text('Удалить заявку'));
    await t.pumpAndSettle();
    // Вопрос и пояснение доступны диктору, а не только кнопки.
    expect(find.bySemanticsLabel('Удалить?'), findsOneWidget);
    expect(find.bySemanticsLabel('Действие нельзя отменить'), findsOneWidget);
    await t.tap(find.text('Удалить'));
    await t.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('Тема: шрифт Onest, без волн, переходы iOS', (t) async {
    final theme = AppTheme.light();
    expect(theme.textTheme.bodyLarge?.fontFamily, AppText.family);
    expect(theme.splashFactory, NoSplash.splashFactory);
    expect(theme.pageTransitionsTheme.builders[TargetPlatform.android],
        isA<CupertinoPageTransitionsBuilder>());
    expect(theme.scaffoldBackgroundColor, AppColors.bg);
  });

  testWidgets('AppFilterChip: обычная и активная с крестиком', (t) async {
    var taps = 0, clears = 0;
    await t.pumpWidget(_app(Column(children: [
      AppFilterChip(label: 'Срочность', onTap: () => taps++),
      AppFilterChip(
          label: 'Статус',
          activeLabel: 'Новая +1',
          clearLabel: 'Убрать',
          onTap: () => taps++,
          onClear: () => clears++),
    ])));
    expect(find.text('Срочность'), findsOneWidget);
    expect(find.text('Новая +1'), findsOneWidget);
    // У обычной — стрелка вниз, у активной — крестик.
    expect(find.byIcon(AppIcons.chevronDown), findsOneWidget);
    expect(find.byIcon(AppIcons.close), findsOneWidget);
    await t.tap(find.text('Срочность'));
    await t.tap(find.byIcon(AppIcons.close));
    await t.pumpAndSettle();
    expect((taps, clears), (1, 1));
    final chip = find.ancestor(
        of: find.text('Новая +1'), matching: find.byType(AppFilterChip));
    final active = t.widget<Container>(
        find.descendant(of: chip, matching: find.byType(Container)).first);
    expect((active.decoration as BoxDecoration).color, AppColors.accentTint);
    // Капсула 34 px, цель нажатия — 44 px.
    expect(t.getSize(chip).height, AppSizes.minTap);
    expect(t.getSize(find.byWidget(active)).height, AppSizes.filterChip);
  });

  testWidgets('AppFilterChip compact: только значок, подпись — для диктора',
      (t) async {
    await t.pumpWidget(_app(AppFilterChip(
        label: 'Сначала новые',
        icon: AppIcons.sort,
        compact: true,
        onTap: () {})));
    expect(find.text('Сначала новые'), findsNothing);
    expect(find.byIcon(AppIcons.sort), findsOneWidget);
    expect(find.bySemanticsLabel('Сначала новые'), findsOneWidget);
  });

  testWidgets('AppCheckRow: галочка у выбранной строки', (t) async {
    var tapped = false;
    await t.pumpWidget(_app(AppGroup(children: [
      AppCheckRow(title: 'Высокий', selected: true, onTap: () {}),
      AppCheckRow(title: 'Низкий', selected: false, onTap: () => tapped = true),
    ])));
    expect(find.byIcon(AppIcons.check), findsOneWidget);
    await t.tap(find.text('Низкий'));
    await t.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('AppFilterPanel: поиск, «Сбросить» и «Применить»', (t) async {
    var applied = false, reset = false;
    String q = '';
    await t.pumpWidget(_app(AppFilterPanel(
      title: 'Объект',
      searchHint: 'Поиск по списку',
      onSearch: (v) => q = v,
      resetLabel: 'Сбросить',
      onReset: () => reset = true,
      applyLabel: 'Применить (2)',
      onApply: () => applied = true,
      children: const [Text('строки')],
    )));
    expect(find.text('Объект'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'плаза');
    await t.tap(find.text('Сбросить'));
    await t.tap(find.text('Применить (2)'));
    await t.pumpAndSettle();
    expect((q, reset, applied), ('плаза', true, true));
  });

  Future<void> openPicker(WidgetTester t, Size size) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(
        Align(
          alignment: Alignment.topLeft,
          child: Builder(
            builder: (ctx) => AppFilterChip(
              label: 'Период',
              onTap: () => showFilterPicker<void>(
                  context: ctx, builder: (_) => const Text('содержимое')),
            ),
          ),
        ),
        size: size));
    await t.tap(find.text('Период'));
    await t.pumpAndSettle();
  }

  testWidgets('showFilterPicker: на узком экране — шторка', (t) async {
    await openPicker(t, const Size(412, 900));
    expect(find.byType(SheetGrabber), findsOneWidget);
    expect(find.text('содержимое'), findsOneWidget);
  });

  testWidgets('showFilterPicker: на широком — окно под таблеткой', (t) async {
    await openPicker(t, const Size(1280, 900));
    expect(find.byType(SheetGrabber), findsNothing);
    final chip = t.getRect(find.byType(AppFilterChip));
    final body = t.getRect(find.text('содержимое'));
    expect(body.top, greaterThan(chip.bottom), reason: 'окно — под таблеткой');
    // Нажатие мимо закрывает окно.
    await t.tapAt(const Offset(1200, 800));
    await t.pumpAndSettle();
    expect(find.text('содержимое'), findsNothing);
  });

  testWidgets('AppFilterPanel: «Применить (N)» не обрезается в окне 360',
      (t) async {
    await t.pumpWidget(_app(Center(
      child: SizedBox(
        width: 360,
        height: 400,
        child: AppFilterPanel(
          title: 'Объект',
          resetLabel: 'Сбросить',
          onReset: () {},
          applyLabel: 'Применить (12)',
          onApply: () {},
          children: const [],
        ),
      ),
    )));
    // «Сбросить» — по ширине текста, «Применить (N)» — всё остальное место
    // (в тестах шрифт шире настоящего, поэтому проверяем раскладку).
    final apply = t.getSize(find.widgetWithText(AppButton, 'Применить (12)'));
    final reset = t.getSize(find.widgetWithText(AppButton, 'Сбросить'));
    expect(apply.width + reset.width + AppSpace.m + 2 * AppSpace.screen,
        moreOrLessEquals(360, epsilon: 1));
    expect(find.text('Сбросить'), findsOneWidget);
  });

  testWidgets('AppFadingScroll: затухание, только если есть что листать',
      (t) async {
    Future<void> pump(int n) => t.pumpWidget(_app(SizedBox(
        width: 300,
        child: AppFadingScroll(
            child: Row(children: [
          for (var i = 0; i < n; i++) const SizedBox(width: 100, height: 30)
        ])))));
    await pump(2);
    await t.pump();
    expect(find.byType(ShaderMask), findsNothing);
    await pump(6);
    await t.pump();
    expect(find.byType(ShaderMask), findsOneWidget);
  });

  group('Шаг 13e: подсказки и панель', () {
    Future<void> openSide(WidgetTester t, Size size) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(_app(
          Builder(
            builder: (ctx) => AppFilterChip(
              label: 'Фильтры',
              onTap: () => showAppSidePanel<void>(
                  context: ctx,
                  builder: (_) => const Center(child: Text('панель'))),
            ),
          ),
          size: size));
      await t.tap(find.text('Фильтры'));
      await t.pumpAndSettle();
    }

    testWidgets('showAppSidePanel: телефон — шторка на весь экран', (t) async {
      await openSide(t, const Size(360, 780));
      expect(find.byType(SheetGrabber), findsOneWidget);
      expect(t.getRect(find.text('панель')).center.dy, greaterThan(300));
    });

    testWidgets('showAppSidePanel: ПК — панель справа 400 px', (t) async {
      await openSide(t, const Size(1280, 800));
      expect(find.byType(SheetGrabber), findsNothing);
      final x = t.getCenter(find.text('панель')).dx;
      expect(x, closeTo(1280 - AppSizes.sidePanel / 2, 1));
    });

    testWidgets('AppInfoButton: цель 44, открывает подсказку', (t) async {
      await t.pumpWidget(_app(const Center(
          child: AppInfoButton(
              title: 'Этажи',
              lines: ['Первая строка', 'Вторая строка'],
              closeLabel: 'Понятно'))));
      expect(t.getSize(find.byType(AppInfoButton)),
          const Size(AppSizes.minTap, AppSizes.minTap));
      await t.tap(find.byType(AppInfoButton));
      await t.pumpAndSettle();
      expect(find.text('Этажи'), findsOneWidget);
      expect(find.text('Вторая строка'), findsOneWidget);
      await t.tap(find.text('Понятно'));
      await t.pumpAndSettle();
      expect(find.text('Вторая строка'), findsNothing);
    });

    testWidgets('AppFilterChip strong: акцентная заливка без стрелки',
        (t) async {
      await t.pumpWidget(_app(Center(
          child: AppFilterChip(
              label: 'Фильтры',
              activeLabel: 'Фильтры · 3',
              strong: true,
              chevron: false,
              icon: AppIcons.filter,
              onTap: () {}))));
      expect(find.text('Фильтры · 3'), findsOneWidget);
      expect(find.byIcon(AppIcons.chevronDown), findsNothing);
      expect(find.byIcon(AppIcons.close), findsNothing);
      final box = t.widget<Container>(find.byType(Container).first);
      expect((box.decoration as BoxDecoration).color, AppColors.accent);
    });
  });
}
