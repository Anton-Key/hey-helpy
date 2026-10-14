import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/acts/act_logic.dart';

ActOrder o(String id,
        {String status = 'done',
        bool photo = true,
        bool filePhoto = false,
        VisitProof visit = VisitProof.inZone,
        bool visitRequired = true,
        int clTotal = 0,
        int clDone = 0,
        bool ppr = false,
        DateTime? date,
        DateTime? due}) =>
    ActOrder(
        id: id,
        title: id,
        status: status,
        date: date ?? DateTime(2026, 10, 5),
        dueAt: due,
        requiresPhoto: true,
        hasAfterPhoto: photo,
        hasFileAfterPhoto: filePhoto,
        visitRequired: visitRequired,
        visit: visit,
        checklistTotal: clTotal,
        checklistDone: clDone,
        isPpr: ppr);

void main() {
  group('Акт подрядчику: к оплате только доказанное', () {
    test('принята + фото + визит в геозоне + чек-лист — к оплате', () {
      final r = buildAct([o('a', clTotal: 3, clDone: 3)], const ActRates());
      expect(r.paid.single.order.id, 'a');
      expect(r.paid.single.photoProof, isTrue);
      expect(r.paid.single.geoProof, isTrue);
      expect(r.paid.single.checklistProof, isTrue);
      expect(r.rejected, isEmpty);
    });

    test('фото «после» только из файла — не доказательство (шаг 26)', () {
      expect(actReasons(o('f', photo: false, filePhoto: true)),
          [ActReason.photoFromFile]);
      // Есть и снимок камеры — к оплате.
      expect(actReasons(o('g', photo: true, filePhoto: true)), isEmpty);
    });

    test('причины словами-кодами', () {
      expect(actReasons(o('x', photo: false)), [ActReason.noPhoto]);
      expect(actReasons(o('x', visit: VisitProof.outOfZone)),
          [ActReason.visitOutOfZone]);
      expect(actReasons(o('x', visit: VisitProof.none)), [ActReason.noVisit]);
      expect(actReasons(o('x', status: 'on_review')), [ActReason.notAccepted]);
      expect(actReasons(o('x', status: 'returned')), [ActReason.returned]);
      expect(actReasons(o('x', clTotal: 5, clDone: 3)), [ActReason.checklist]);
      expect(actReasons(o('x', status: 'on_review', photo: false)),
          [ActReason.notAccepted, ActReason.noPhoto]);
    });

    test('без геозоны у объекта визит не нужен; без requires_photo — фото', () {
      expect(actReasons(o('x', visitRequired: false, visit: VisitProof.none)),
          isEmpty);
      final noPhotoNeeded = ActOrder(
          id: 'y', title: 'y', status: 'done', date: _d, requiresPhoto: false);
      expect(actReasons(noPhotoNeeded), isEmpty);
    });

    test('суммы: за заявку и за визит ТО; без ставок — без сумм', () {
      const rates = ActRates(perOrder: 4500, perVisit: 2500);
      final r = buildAct(
          [o('a'), o('b', ppr: true), o('c', photo: false)], rates);
      expect(r.paid.map((x) => x.amount), [4500, 2500]);
      expect(r.sum, 7000);
      expect(r.rejected.single.amount, isNull);
      expect(buildAct([o('a')], const ActRates()).sum, isNull);
      // Ставки за визит нет — задача ТО по ставке за заявку.
      expect(buildAct([o('b', ppr: true)], const ActRates(perOrder: 100)).sum,
          100);
    });

    test('доля доказанных и просроченные', () {
      final r = buildAct([
        o('a', date: DateTime(2026, 10, 9), due: DateTime(2026, 10, 8)),
        o('b'),
        o('c', photo: false),
        o('d', status: 'on_review'),
      ], const ActRates());
      expect(r.provenShare, 0.5);
      expect(r.overdue, 1);
      expect(r.paid.first.order.id, 'b'); // по дате
      expect(buildAct(const [], const ActRates()).provenShare, isNull);
    });

    test('период месяца и попадание в него', () {
      final (from, to) = monthRange(DateTime(2026, 12, 15));
      expect(from, DateTime(2026, 12));
      expect(to, DateTime(2027, 1));
      expect(inActPeriod(o('a', date: DateTime(2026, 12, 31, 23)), from, to),
          isTrue);
      expect(inActPeriod(o('a', date: DateTime(2027, 1, 1)), from, to), isFalse);
    });

    test('снимок для базы и имя файла', () {
      final r = buildAct([o('a'), o('c', photo: false)],
          const ActRates(perOrder: 10, currency: 'RUB'));
      final items = actItemsJson(r);
      expect(items.first['paid'], isTrue);
      expect(items.last['reasons'], ['noPhoto']);
      expect(actTotalsJson(r)['sum'], 10);
      expect(actFileBase('АКТ-2026-003'), 'AKT-2026-003');
    });
  });
}

final _d = DateTime.utc(2026, 10, 5);
