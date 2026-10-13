import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_message.dart';
import 'l10n_ext.dart';

/// Веб-версия: «Скачать» / «Открыть»; телефон: «Поделиться».
const bool isWebPlatform = kIsWeb;

/// Подписанная ссылка Storage с заголовком «скачать как <имя>».
/// Параметр `download` понимает сам Supabase Storage.
String downloadUrl(String signedUrl, String fileName) {
  final sep = signedUrl.contains('?') ? '&' : '?';
  return '$signedUrl${sep}download=${Uri.encodeQueryComponent(fileName)}';
}

/// Открыть файл по подписанной ссылке в новой вкладке (веб) или
/// в системном приложении (телефон): PDF — просмотрщик, остальное —
/// браузер скачает сам.
Future<void> openStorageUrl(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url),
      mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
  if (!ok && context.mounted) {
    showAppMessage(context, context.l10n.fileOpenFailed,
        type: AppMessageType.error);
  }
}

/// «Скачать» (веб — файл с именем по ссылке) или «Поделиться» (Android —
/// системное окно, файл передаётся байтами, а не ссылкой на хранилище).
Future<void> shareStorageFile({
  required BuildContext context,
  required String url,
  required String fileName,
  required String mime,
  required Future<Uint8List> Function() bytes,
}) async {
  final l = context.l10n;
  try {
    if (kIsWeb) {
      await openStorageUrl(context, downloadUrl(url, fileName));
      return;
    }
    final data = await bytes();
    await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(data, mimeType: mime, name: fileName)],
        fileNameOverrides: [fileName]));
  } catch (e) {
    debugPrint('share: ${e.runtimeType}');
    if (context.mounted) {
      showAppMessage(context, l.fileOpenFailed, type: AppMessageType.error);
    }
  }
}
