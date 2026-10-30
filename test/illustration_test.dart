import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/core/design/design.dart';

/// Шаг 33: иллюстрации-концепт — файлы на месте (только WebP в сборке),
/// у картинки всегда есть пометка «Иллюстрация» и описание для читалок.
void main() {
  test('у каждой иллюстрации есть WebP в assets/illustrations/', () {
    for (final n in AppIllustrationName.values) {
      final f = File(illustrationAsset(n));
      expect(f.existsSync(), isTrue, reason: f.path);
      expect(f.path.endsWith('.webp'), isTrue);
    }
  });

  test('в сборку идут только WebP (PNG-исходники — в assets/marketing/)', () {
    final files = Directory('assets/illustrations').listSync().whereType<File>();
    expect(files.where((f) => !f.path.endsWith('.webp')), isEmpty);
    expect(File('pubspec.yaml').readAsStringSync(),
        isNot(matches(RegExp(r'^\s*- assets/marketing', multiLine: true))));
  });

  testWidgets('подпись «Иллюстрация» и описание для читалок', (t) async {
    await t.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: AppIllustration(AppIllustrationName.phone,
                note: 'Illustration',
                semanticLabel: 'Phone pointed at an AC',
                caption: 'How AR labels work'))));
    expect(find.text('Illustration'), findsOneWidget);
    expect(find.text('How AR labels work'), findsOneWidget);
    expect(find.bySemanticsLabel('Phone pointed at an AC'), findsOneWidget);
  });

  testWidgets('пустое состояние с картинкой вместо значка', (t) async {
    await t.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: AppEmptyState(
                text: 'No work orders yet',
                image: AppIllustration(AppIllustrationName.faucet,
                    note: 'Illustration', semanticLabel: 'Leaking faucet')))));
    expect(find.byType(AppIllustration), findsOneWidget);
    expect(find.byIcon(AppIcons.inbox), findsNothing);
  });
}
