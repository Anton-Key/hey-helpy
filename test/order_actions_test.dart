import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/requests/order_actions.dart';

const mgr = OrderActor(role: 'manager', uid: 'm1');
const admin = OrderActor(role: 'admin', uid: 'a1');
const exec = OrderActor(role: 'executor', uid: 'e1', contractorIds: {'c1'});
const otherExec =
    OrderActor(role: 'executor', uid: 'e2', contractorIds: {'c2'});
const requester = OrderActor(role: 'requester', uid: 'r1');

/// Менеджер «собственной службы»: исполнитель подрядчика c1.
const ownService =
    OrderActor(role: 'manager', uid: 'm2', contractorIds: {'c1'});

OrderActions can(OrderActor who, String status,
        {String? contractor = 'c1',
        String? createdBy = 'r1',
        String? submittedBy}) =>
    orderActions(who,
        status: status,
        createdBy: createdBy,
        contractorId: contractor,
        submittedBy: submittedBy);

void main() {
  group('начать работу и сдать — только исполнитель назначенного подрядчика',
      () {
    for (final s in ['new', 'assigned', 'returned']) {
      test('начать из «$s»', () {
        expect(can(exec, s).start, isTrue);
        expect(can(mgr, s).start, isFalse);
        expect(can(admin, s).start, isFalse);
        expect(can(requester, s).start, isFalse);
        expect(can(otherExec, s).start, isFalse);
      });
    }
    test('в работе: фото «после» и на проверку', () {
      final e = can(exec, 'in_progress');
      expect(e.addAfterPhoto, isTrue);
      expect(e.submit, isTrue);
      for (final who in [mgr, admin, requester, otherExec]) {
        final a = can(who, 'in_progress');
        expect(a.addAfterPhoto, isFalse, reason: who.role);
        expect(a.submit, isFalse, reason: who.role);
      }
    });
    test('без подрядчика никто не начинает, менеджеру — подсказка', () {
      for (final who in [exec, mgr, admin, ownService]) {
        expect(can(who, 'new', contractor: null).start, isFalse);
      }
      expect(can(mgr, 'new', contractor: null).assignFirstHint, isTrue);
      expect(can(exec, 'new', contractor: null).assignFirstHint, isFalse);
      expect(can(mgr, 'new').assignFirstHint, isFalse);
    });
    test('своя служба: менеджер-исполнитель начинает и сдаёт', () {
      expect(can(ownService, 'assigned').start, isTrue);
      expect(can(ownService, 'in_progress').submit, isTrue);
      expect(can(ownService, 'in_progress').watchProgress, isFalse);
    });
  });

  group('принять / вернуть — менеджер, не тот, кто сдал', () {
    test('менеджер и админ принимают', () {
      expect(can(mgr, 'on_review', submittedBy: 'e1').accept, isTrue);
      expect(can(admin, 'on_review', submittedBy: 'e1').accept, isTrue);
      expect(can(mgr, 'on_review').accept, isTrue, reason: 'старые данные');
    });
    test('исполнитель и автор-заявитель — нет', () {
      expect(can(exec, 'on_review', submittedBy: 'e1').accept, isFalse);
      expect(can(requester, 'on_review', submittedBy: 'e1').accept, isFalse);
    });
    test('сдавший сам не принимает, пояснение', () {
      final a = can(ownService, 'on_review', submittedBy: 'm2');
      expect(a.accept, isFalse);
      expect(a.otherManagerMustAccept, isTrue);
      expect(can(mgr, 'on_review', submittedBy: 'm2').accept, isTrue);
    });
    test('принять можно только на проверке', () {
      for (final s in ['new', 'assigned', 'in_progress', 'done', 'returned']) {
        expect(can(mgr, s).accept, isFalse, reason: s);
      }
    });
  });

  group('менеджер видит ход работы, а не кнопки исполнителя', () {
    test('строка-статус в работе', () {
      expect(can(mgr, 'in_progress').watchProgress, isTrue);
      expect(can(exec, 'in_progress').watchProgress, isFalse);
      expect(can(mgr, 'assigned').watchProgress, isFalse);
    });
  });

  group('назначить, править, отменить', () {
    test('назначает менеджер, пока работу не начали', () {
      for (final s in ['new', 'assigned', 'returned']) {
        expect(can(mgr, s).assign, isTrue, reason: s);
        expect(can(requester, s).assign, isFalse, reason: s);
      }
      expect(can(mgr, 'in_progress').assign, isFalse);
    });
    test('автор правит и отменяет, пока работа не начата', () {
      for (final s in ['new', 'assigned']) {
        expect(can(requester, s).edit, isTrue, reason: s);
        expect(can(requester, s).cancel, isTrue, reason: s);
      }
      for (final s in ['in_progress', 'on_review', 'returned']) {
        expect(can(requester, s).edit, isFalse, reason: s);
        expect(can(requester, s).cancel, isFalse, reason: s);
      }
    });
    test('менеджер отменяет до приёмки; закрытую — никто', () {
      expect(can(mgr, 'in_progress').cancel, isTrue);
      expect(can(mgr, 'on_review').cancel, isTrue);
      expect(can(mgr, 'done').cancel, isFalse);
      expect(can(mgr, 'cancelled').cancel, isFalse);
      expect(can(exec, 'assigned').cancel, isFalse);
    });
    test('фото «до» — автор и менеджер до начала работы', () {
      expect(can(requester, 'new').addBeforePhoto, isTrue);
      expect(can(mgr, 'assigned').addBeforePhoto, isTrue);
      expect(can(exec, 'assigned').addBeforePhoto, isFalse);
      expect(can(requester, 'in_progress').addBeforePhoto, isFalse);
    });
  });
}
