import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/floors/floor_repository.dart';
import 'package:hey_helpy/features/floors/plan_sheets.dart';
import 'package:hey_helpy/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('ru'));
  const rls = StorageException('new row violates row-level security policy',
      statusCode: '403');

  group('planErrorText — подпись по роли (ошибка 0013)', () {
    test('менеджер: отказ хранилища — «Хранилище отклонило», с кодом', () {
      final t = planErrorText(l, rls, isManager: true);
      expect(t, l.planStorageDenied('403'));
      expect(t, contains('403'));
      expect(t, isNot(l.planNoRights));
    });

    test('менеджер: RLS с кодом 400 — тоже отказ хранилища', () {
      const e = StorageException('new row violates row-level security policy',
          statusCode: '400');
      expect(planErrorText(l, e, isManager: true), l.planStorageDenied('400'));
    });

    test('не менеджер: «только менеджер»', () {
      expect(planErrorText(l, rls, isManager: false), l.planNoRights);
      expect(planErrorText(l, const FloorDenied(), isManager: false),
          l.planNoRights);
    });

    test('менеджер: отказ базы — не «только менеджер»', () {
      const e = PostgrestException(message: 'denied', code: '42501');
      expect(planErrorText(l, e, isManager: true), l.planDbDenied('42501'));
      expect(planErrorText(l, const FloorDenied(), isManager: true),
          isNot(l.planNoRights));
    });

    test('размер и тип файла — одинаково для всех ролей', () {
      const big = StorageException('too big', statusCode: '413');
      expect(planErrorText(l, big, isManager: true), l.planTooBig);
      expect(planErrorText(l, big, isManager: false), l.planTooBig);
    });

    test('прочее — «не удалось загрузить»', () {
      const e = StorageException('boom', statusCode: '500');
      expect(planErrorText(l, e, isManager: true), l.planUploadFailed);
    });
  });
}
