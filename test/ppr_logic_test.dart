import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hey_helpy/features/directory/directory.dart';
import 'package:hey_helpy/features/ppr/ppr_logic.dart';
import 'package:hey_helpy/features/ppr/ppr_repository.dart';
import 'package:hey_helpy/features/ppr/ppr_text.dart';
import 'package:hey_helpy/features/ppr/ppr_view.dart';
import 'package:hey_helpy/l10n/app_localizations.dart';

DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);

MaintenancePlan plan(String id,
        {PeriodKind kind = PeriodKind.month,
        int? days,
        String object = 'o1',
        String layer = 'hvac',
        bool active = true,
        DateTime? starts}) =>
    MaintenancePlan(
        id: id,
        objectId: object,
        layerId: layer,
        title: 'План $id',
        kind: kind,
        days: days,
        startsOn: starts ?? d(2026, 1, 1),
        active: active);

PlanTask task(String plan, String status, PeriodBounds p) => PlanTask(
    id: 't-$plan-${p.start.month}',
    planId: plan,
    status: status,
    period: p,
    row: const {});

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru');
    await initializeDateFormatting('en');
  });

  group('Границы периодов (как period_bounds в базе)', () {
    test('месяц, включая конец года и февраль', () {
      expect(periodBounds(PeriodKind.month, on: d(2026, 10, 10)),
          PeriodBounds(d(2026, 10, 1), d(2026, 10, 31)));
      expect(periodBounds(PeriodKind.month, on: d(2026, 12, 31)),
          PeriodBounds(d(2026, 12, 1), d(2026, 12, 31)));
      expect(periodBounds(PeriodKind.month, on: d(2024, 2, 15)).end,
          d(2024, 2, 29));
      expect(periodBounds(PeriodKind.month, on: d(2026, 2, 1)).end,
          d(2026, 2, 28));
    });

    test('квартал, полугодие, год', () {
      expect(periodBounds(PeriodKind.quarter, on: d(2026, 10, 10)),
          PeriodBounds(d(2026, 10, 1), d(2026, 12, 31)));
      expect(periodBounds(PeriodKind.quarter, on: d(2026, 3, 31)),
          PeriodBounds(d(2026, 1, 1), d(2026, 3, 31)));
      expect(periodBounds(PeriodKind.halfYear, on: d(2026, 6, 30)),
          PeriodBounds(d(2026, 1, 1), d(2026, 6, 30)));
      expect(periodBounds(PeriodKind.halfYear, on: d(2026, 7, 1)),
          PeriodBounds(d(2026, 7, 1), d(2026, 12, 31)));
      expect(periodBounds(PeriodKind.year, on: d(2028, 2, 29)),
          PeriodBounds(d(2028, 1, 1), d(2028, 12, 31)));
    });

    test('каждые N дней — от даты начала, через конец года и до начала', () {
      expect(
          periodBounds(PeriodKind.days,
              days: 10, startsOn: d(2026, 10, 1), on: d(2026, 10, 10)),
          PeriodBounds(d(2026, 10, 1), d(2026, 10, 10)));
      expect(
          periodBounds(PeriodKind.days,
              days: 10, startsOn: d(2026, 10, 1), on: d(2026, 10, 11)),
          PeriodBounds(d(2026, 10, 11), d(2026, 10, 20)));
      expect(
          periodBounds(PeriodKind.days,
              days: 7, startsOn: d(2026, 12, 28), on: d(2027, 1, 4)),
          PeriodBounds(d(2027, 1, 4), d(2027, 1, 10)));
      expect(
          periodBounds(PeriodKind.days,
              days: 10, startsOn: d(2026, 10, 1), on: d(2026, 9, 30)),
          PeriodBounds(d(2026, 9, 21), d(2026, 9, 30)));
      // Високосный февраль внутри шага: 1 февраля + 30 дней = 1 марта.
      expect(
          periodBounds(PeriodKind.days,
              days: 30, startsOn: d(2028, 2, 1), on: d(2028, 3, 1)),
          PeriodBounds(d(2028, 2, 1), d(2028, 3, 1)));
    });

    test('предыдущий период', () {
      final cur = periodBounds(PeriodKind.quarter, on: d(2026, 1, 5));
      expect(previousPeriod(PeriodKind.quarter, cur),
          PeriodBounds(d(2025, 10, 1), d(2025, 12, 31)));
    });

    test('коды периодичности', () {
      expect(PeriodKind.fromCode('half_year'), PeriodKind.halfYear);
      expect(PeriodKind.fromCode('нет'), isNull);
      expect(PeriodKind.days.code, 'days');
    });
  });

  group('Подписи периода', () {
    final ru = lookupAppLocalizations(const Locale('ru'));
    final en = lookupAppLocalizations(const Locale('en'));

    test('русский и английский', () {
      expect(pprPeriodText(ru, PeriodKind.month,
          PeriodBounds(d(2026, 10, 1), d(2026, 10, 31))), 'октябрь 2026');
      expect(pprPeriodText(en, PeriodKind.month,
          PeriodBounds(d(2026, 10, 1), d(2026, 10, 31))), 'October 2026');
      expect(pprPeriodText(ru, PeriodKind.quarter,
          PeriodBounds(d(2026, 10, 1), d(2026, 12, 31))), 'IV кв. 2026');
      expect(pprPeriodText(en, PeriodKind.quarter,
          PeriodBounds(d(2026, 10, 1), d(2026, 12, 31))), 'Q4 2026');
      expect(pprPeriodText(ru, PeriodKind.halfYear,
          PeriodBounds(d(2026, 7, 1), d(2026, 12, 31))), 'II полугодие 2026');
      expect(pprPeriodText(en, PeriodKind.halfYear,
          PeriodBounds(d(2026, 1, 1), d(2026, 6, 30))), 'H1 2026');
      expect(pprPeriodText(ru, PeriodKind.year,
          PeriodBounds(d(2026, 1, 1), d(2026, 12, 31))), '2026 год');
      expect(pprPeriodText(ru, PeriodKind.days,
          PeriodBounds(d(2026, 10, 1), d(2026, 10, 10))), '01.10–10.10.2026');
    });

    test('периодичность словами', () {
      expect(pprEvery(ru, PeriodKind.month, null), 'каждый месяц');
      expect(pprEvery(ru, PeriodKind.days, 3), 'каждые 3 дня');
      expect(pprEvery(ru, PeriodKind.days, 10), 'каждые 10 дней');
      expect(pprEvery(en, PeriodKind.days, 10), 'every 10 days');
    });

    test('строка задачи периода в списке и карточке', () {
      final line = pprTaskLine(ru,
          recurrence: const {'kind': 'ppr', 'period': 'month'},
          periodStart: '2026-10-01',
          periodEnd: '2026-10-31');
      expect(line, startsWith('ППР · октябрь 2026 · до 31'));
      // Без recurrence вид периода угадывается по границам.
      expect(
          pprTaskLine(en,
              recurrence: null,
              periodStart: '2026-10-01',
              periodEnd: '2026-12-31'),
          startsWith('PPM · Q4 2026 · due'));
      // База без 0015 — полей нет.
      expect(
          pprTaskLine(ru,
              recurrence: const {'kind': 'regular'},
              periodStart: null,
              periodEnd: null),
          isNull);
    });

    test('задача ППР — по plan_id или recurrence.kind', () {
      expect(isPprOrder({'plan_id': 'x'}), isTrue);
      expect(isPprOrder({'recurrence': {'kind': 'ppr'}}), isTrue);
      expect(isPprOrder({'recurrence': {'kind': 'regular'}}), isFalse);
      expect(isPprOrder({}), isFalse);
    });
  });

  group('Состояние периода и список планов', () {
    final oct = PeriodBounds(d(2026, 10, 1), d(2026, 10, 31));
    final now = DateTime(2026, 10, 10, 12);

    test('состояние по задаче', () {
      expect(periodState(active: true, task: null, period: oct, now: now),
          PeriodState.notStarted);
      expect(periodState(active: true, task: 'assigned', period: oct, now: now),
          PeriodState.notStarted);
      expect(periodState(active: true, task: 'on_review', period: oct, now: now),
          PeriodState.inProgress);
      expect(periodState(active: true, task: 'done', period: oct, now: now),
          PeriodState.done);
      expect(periodState(active: false, task: null, period: oct, now: now),
          PeriodState.paused);
      expect(
          periodState(
              active: true,
              task: 'in_progress',
              period: PeriodBounds(d(2026, 9, 1), d(2026, 9, 30)),
              now: now),
          PeriodState.overdue);
      // Последний день периода — ещё не просрочено.
      expect(
          periodState(
              active: true,
              task: 'assigned',
              period: oct,
              now: DateTime(2026, 10, 31, 23)),
          PeriodState.notStarted);
    });

    test('подрядчик плана: закрепление на объект важнее «на все объекты»', () {
      final contractors = [
        Contractor(id: 'all', orgName: 'Все'),
        Contractor(id: 'obj', orgName: 'Объект'),
      ];
      const hvac = Layer(id: 'hvac', name: 'Климат');
      final bindings = [
        const Binding(id: 'b1', contractorId: 'all', layer: hvac),
        const Binding(id: 'b2', contractorId: 'obj', layer: hvac, objectId: 'o1'),
      ];
      expect(planContractor(plan('p1'), bindings, contractors)?.id, 'obj');
      expect(planContractor(plan('p2', object: 'o2'), bindings, contractors)?.id,
          'all');
      expect(planContractor(plan('p3', layer: 'elec'), bindings, contractors),
          isNull);
    });

    test('список: состояние, порядок, фильтр, сводка', () {
      final views = buildPlanViews(
        plans: [
          plan('done'),
          plan('none'),
          plan('paused', active: false),
          plan('q', kind: PeriodKind.quarter, layer: 'elec'),
        ],
        tasks: [
          task('done', 'done', oct),
          task('q', 'in_progress',
              PeriodBounds(d(2026, 10, 1), d(2026, 12, 31))),
          // Прошлый период не влияет на текущий.
          task('none', 'done', PeriodBounds(d(2026, 9, 1), d(2026, 9, 30))),
        ],
        objects: [Obj(id: 'o1', name: 'Офис 1', type: 'office', city: 'Москва')],
        layers: const [],
        contractors: const [],
        bindings: const [],
        now: now,
      );
      expect([for (final v in views) v.state], [
        PeriodState.notStarted,
        PeriodState.inProgress,
        PeriodState.done,
        PeriodState.paused,
      ]);
      expect(views.first.objectLabel, 'Москва · Офис 1');

      final sum = pprMonthSummary(views);
      expect(sum, (done: 1, total: 3));

      const f = PprFilter(states: {PeriodState.done, PeriodState.inProgress});
      expect(f.activeCount, 1);
      expect([for (final v in views) if (f.matches(v)) v.plan.id], ['q', 'done']);
      final g = f.copyWith(layers: {'elec'});
      expect(g.activeCount, 2);
      expect([for (final v in views) if (g.matches(v)) v.plan.id], ['q']);
      const noContractor = PprFilter(contractors: {''});
      expect(views.where(noContractor.matches).length, 4);
    });

    test('генерация не чаще раза в 10 минут', () {
      final t = DateTime(2026, 10, 10, 9);
      expect(pprGenerateDue(null, t), isTrue);
      expect(pprGenerateDue(t, t.add(const Duration(minutes: 9))), isFalse);
      expect(pprGenerateDue(t, t.add(const Duration(minutes: 10))), isTrue);
    });

    test('план из строки базы и обратно', () {
      final p = MaintenancePlan.fromMap({
        'id': 'p',
        'object_id': 'o',
        'layer_id': 'y',
        'title': ' ТО ',
        'period_kind': 'days',
        'period_days': 14,
        'starts_on': '2026-10-01',
        'checklist': ['Фильтры', '  ', 3, 'Дренаж'],
        'requires_photo': false,
        'priority': 'high',
        'active': false,
      });
      expect(p.kind, PeriodKind.days);
      expect(p.checklist, ['Фильтры', 'Дренаж']);
      final row = p.toRow();
      expect(row['period_days'], 14);
      expect(row['starts_on'], '2026-10-01');
      expect(row['title'], 'ТО');
      expect(p.currentPeriod(DateTime(2026, 10, 20)),
          PeriodBounds(d(2026, 10, 15), d(2026, 10, 28)));
    });
  });
}
