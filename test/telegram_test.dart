import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/core/app_links.dart';
import 'package:hey_helpy/core/design/design.dart';
import 'package:hey_helpy/features/reports/report_pdf.dart';
import 'package:hey_helpy/features/requests/order_filter.dart';
import 'package:hey_helpy/features/telegram/telegram_poster.dart';
import 'package:hey_helpy/features/telegram/telegram_repository.dart';
import 'package:hey_helpy/l10n/app_localizations.dart';

Future<ByteData> _fontFromFile(String asset) async =>
    ByteData.sublistView(Uint8List.fromList(await File(asset).readAsBytes()));

void main() {
  final ru = lookupAppLocalizations(const Locale('ru'));
  final en = lookupAppLocalizations(const Locale('en'));

  group('ссылки на бота', () {
    test('имя бота совпадает с функцией telegram-bot', () {
      final ts = File('supabase/functions/telegram-bot/telegram.ts')
          .readAsStringSync();
      expect(ts, contains('BOT_USERNAME = "$kTelegramBot"'));
    });

    test('start и startgroup — параметры, которые понимает бот', () {
      expect(telegramStartLink('link_ABCD2345'),
          'https://t.me/HeyHelpy_bot?start=link_ABCD2345');
      expect(telegramGroupLink('ABCD2345'),
          'https://t.me/HeyHelpy_bot?startgroup=grp_ABCD2345');
      const obj = ReportLink(id: '1', token: 'tok_-123', objectId: 'o1');
      const co = ReportLink(id: '2', token: 'tok_-456');
      expect(obj.url, endsWith('?start=obj_tok_-123'));
      expect(co.url, endsWith('?start=co_tok_-456'));
      // Telegram: параметр start — до 64 знаков A–Z a–z 0–9 _ -.
      for (final u in [obj.url, co.url, telegramGroupLink('ABCD2345')]) {
        final p = Uri.parse(u).queryParameters.values.single;
        expect(RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(p), isTrue, reason: u);
      }
    });
  });

  group('автор из Telegram', () {
    test('не из Telegram — null', () {
      expect(telegramReporterLabel(ru, null), isNull);
      expect(telegramReporterLabel(ru, 'x'), isNull);
    });

    test('сотрудник, гость, группа', () {
      expect(
          telegramReporterLabel(
              ru, {'name': 'Мария К.', 'username': 'maria', 'guest': false}),
          'Мария К. (@maria)');
      expect(telegramReporterLabel(ru, {'name': 'Мария К.', 'guest': true}),
          'Мария К. · гость');
      expect(
          telegramReporterLabel(
              en, {'username': 'ivan', 'guest': true, 'group': 'Demo BC'}),
          '@ivan · from a group: Demo BC');
      expect(telegramReporterLabel(ru, {'guest': true}), 'Telegram · гость');
    });
  });

  test('фильтр «Источник» знает канал telegram', () {
    expect(kChannels, contains('telegram'));
    const f = OrderFilter(channels: {'telegram', 'voice'});
    expect(f.serverConditions(now: DateTime(2026, 10, 13)).map((c) => '$c'),
        contains('input_channel=in.(voice,telegram)'));
    expect(OrderFilter.fromQuery({'src': 'telegram'}).channels, {'telegram'});
  });

  group('QR-код', () {
    test('модули квадратные, сетка QR с полем', () {
      final url = telegramStartLink('obj_${'x' * 24}');
      final mods = qrModules(url, 300);
      expect(mods, isNotEmpty);
      // Всё внутри квадрата и не на поле (2 модуля по краям).
      final cell = mods.map((r) => r.height).reduce((a, b) => a < b ? a : b);
      for (final r in mods) {
        expect(r.left, greaterThanOrEqualTo(cell * 2 - 0.01));
        expect(r.top, greaterThanOrEqualTo(cell * 2 - 0.01));
        expect(r.right, lessThanOrEqualTo(300 - cell * 2 + 0.01));
        expect(r.bottom, lessThanOrEqualTo(300 - cell * 2 + 0.01));
      }
      // Версия QR: 21 + 4k модулей по стороне.
      final n = (300 / cell).round() - 4;
      expect((n - 21) % 4, 0, reason: 'модулей: $n');
    });

    testWidgets('виджет рисуется', (t) async {
      await t.pumpWidget(const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: AppQrCode('https://t.me/HeyHelpy_bot'))));
      expect(find.byType(AppQrCode), findsOneWidget);
    });
  });

  test('плакат PDF собирается на обоих языках', () async {
    final fonts = await loadReportFonts(_fontFromFile);
    for (final l in [ru, en]) {
      final bytes = await buildPosterPdf(
          l: l,
          fonts: fonts,
          objectName: 'Белград · БЦ «Демо»',
          url: telegramStartLink('obj_abcdefghijklmnopqrstuvwx'));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(5000));
    }
  });

  test('строки Telegram есть на обоих языках', () {
    expect(ru.tgPosterTitle, isNot(en.tgPosterTitle));
    expect(ru.tgGroupCodeHowTo(kTelegramBot, 'ABCD2345'),
        contains('/connect ABCD2345'));
    expect(en.tgSettingsHint(kTelegramBot), contains('@HeyHelpy_bot'));
  });
}
