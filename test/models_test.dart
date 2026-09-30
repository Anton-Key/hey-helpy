import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/requests/requests.dart';
import 'package:hey_helpy/models/user_role.dart';

void main() {
  group('UserRole', () {
    test('неизвестная роль превращается в requester', () {
      expect(UserRole.fromString('boss'), UserRole.requester);
      expect(UserRole.fromString(null), UserRole.requester);
      expect(UserRole.fromString('manager'), UserRole.manager);
    });

    test('права по ролям', () {
      expect(UserRole.admin.canAdmin, isTrue);
      expect(UserRole.manager.canAdmin, isFalse);
      expect(UserRole.manager.canManage, isTrue);
      expect(UserRole.executor.canSeeReports, isFalse);
    });
  });

  group('WorkOrderDraft', () {
    test('обрезает пробелы и превращает пустое описание в null', () {
      final d = WorkOrderDraft(title: '  Течёт кран ', description: '   ');
      expect(d.title, 'Течёт кран');
      expect(d.description, isNull);
      expect(d.recurrence, isNull);
    });

    test('регламентная заявка хранит период', () {
      final d = WorkOrderDraft(title: 'Фильтры', period: 'month');
      expect(d.recurrence, {'kind': 'regular', 'period': 'month'});
    });
  });

  group('recurrence', () {
    test('старые записи без периода считаются еженедельными', () {
      expect(recurrencePeriod({'kind': 'regular'}), 'week');
      expect(recurrencePeriod(null), isNull);
      expect(recurrencePeriod({'kind': 'regular', 'period': 'day'}), 'day');
      expect(recurrenceLabel(null), 'Разовая');
      expect(recurrenceLabel({'period': 'month'}), 'Регламентная · ежемесячно');
    });
  });

  group('WorkOrder', () {
    Map<String, dynamic> row({String status = 'new', String? due}) => {
          'id': '1', 'title': 'T', 'priority': 'high', 'status': status,
          'recurrence': null, 'object_id': null, 'due_at': due,
        };

    test('просрочка только для незакрытых заявок с прошедшим сроком', () {
      final past = DateTime.now().subtract(const Duration(days: 1)).toUtc().toIso8601String();
      final future = DateTime.now().add(const Duration(days: 1)).toUtc().toIso8601String();
      expect(WorkOrder.fromMap(row(due: past)).isOverdue, isTrue);
      expect(WorkOrder.fromMap(row(due: past, status: 'done')).isOverdue, isFalse);
      expect(WorkOrder.fromMap(row(due: future)).isOverdue, isFalse);
      expect(WorkOrder.fromMap(row()).isOverdue, isFalse);
    });
  });

  test('ошибки сервера переводятся в понятный текст', () {
    expect(humanizeSaveError(Exception('title is required')), 'Опишите проблему в двух словах');
    expect(humanizeSaveError(Exception('Could not find the function public.create_work_order')),
        contains('миграцию 0003'));
    expect(humanizeStatusError(Exception('status transition not allowed')), contains('недоступно'));
  });
}
