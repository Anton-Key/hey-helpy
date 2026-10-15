import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../l10n/app_localizations.dart';
import 'offline_logic.dart';
import 'offline_service.dart';

/// Тонкая плашка вверху (шаг 27): «Нет сети — сохранено на телефоне:
/// 4 действия», «Нет сети · данные на 14:02», «Отправляю…», «Отправлено ✓»,
/// «Не удалось отправить 1 действие · Подробнее». Всё в порядке — пусто.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.service});
  final OfflineService? service;

  @override
  Widget build(BuildContext context) {
    final s = service ?? OfflineService.instance;
    if (!OfflineService.supported) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final l = context.l10n;
        final (text, colors, icon, details) = _state(l, s);
        return Column(mainAxisSize: MainAxisSize.min, children: [
          if (OfflineService.testMode) _TestSwitch(service: s),
          if (text != null)
            Semantics(
              liveRegion: true,
              child: Container(
                width: double.infinity,
                color: colors!.background,
                padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpace.l, vertical: AppSpace.s),
                child: Row(children: [
                  Icon(icon, size: 16, color: colors.foreground),
                  const SizedBox(width: AppSpace.s),
                  Expanded(
                    child: Text(text,
                        style: AppText.footnote.copyWith(
                            color: colors.foreground,
                            fontWeight: FontWeight.w600)),
                  ),
                  if (details)
                    Pressable(
                      onTap: () => showSyncFailures(context, s),
                      child: Padding(
                        padding:
                            const EdgeInsetsDirectional.only(start: AppSpace.s),
                        child: Text(l.offDetails,
                            style: AppText.footnote.copyWith(
                                color: colors.foreground,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline)),
                      ),
                    ),
                ]),
              ),
            ),
        ]);
      },
    );
  }

  (String?, StatusColors?, IconData?, bool) _state(
      AppLocalizations l, OfflineService s) {
    if (s.failures.isNotEmpty && s.online && s.pending == 0) {
      return (
        l.offBannerFailed(s.failures.length),
        StatusColors.overdue,
        AppIcons.warning,
        true
      );
    }
    if (s.justSent && s.pending == 0) {
      return (l.offBannerSent, StatusColors.done, AppIcons.success, false);
    }
    if (s.sending) {
      return (
        l.offBannerSending,
        StatusColors.inProgress,
        AppIcons.uploadPending,
        false
      );
    }
    if (!s.online) {
      if (s.pending > 0) {
        return (
          l.offBannerQueued(s.pending),
          StatusColors.returned,
          AppIcons.offline,
          false
        );
      }
      final at = s.cacheAt;
      return (
        at == null ? l.offBannerNoData : l.offBannerData(l.time(at)),
        StatusColors.cancelled,
        AppIcons.offline,
        false
      );
    }
    if (s.pending > 0) {
      return (
        l.offBannerQueued(s.pending),
        StatusColors.returned,
        AppIcons.uploadPending,
        false
      );
    }
    return (null, null, null, false);
  }
}

/// Причина отказа словами.
String syncReasonText(AppLocalizations l, SyncReason r) => switch (r) {
      SyncReason.cancelled => l.offReasonCancelled,
      SyncReason.reassigned => l.offReasonReassigned,
      SyncReason.accepted => l.offReasonAccepted,
      SyncReason.onReview => l.offReasonOnReview,
      SyncReason.photoRequired => l.offReasonPhotoRequired,
      SyncReason.photoMismatch => l.offReasonPhotoMismatch,
      SyncReason.photoMissing => l.offReasonPhotoMissing,
      SyncReason.notFound => l.offReasonNotFound,
      SyncReason.denied => l.offReasonDenied,
      SyncReason.other => l.offReasonOther,
    };

String offlineKindText(AppLocalizations l, OfflineKind k) => switch (k) {
      OfflineKind.start => l.offKindStart,
      OfflineKind.visit => l.offKindVisit,
      OfflineKind.check => l.offKindCheck,
      OfflineKind.photo => l.offKindPhoto,
      OfflineKind.submit => l.offKindSubmit,
    };

/// «Подробнее»: что не отправилось и почему.
Future<void> showSyncFailures(BuildContext context, OfflineService s) {
  final l = context.l10n;
  return showAppSheet<void>(
    context: context,
    builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
      SheetHeader(
          title: l.offFailuresTitle,
          doneLabel: l.offFailuresClear,
          onDone: () {
            s.clearFailures();
            Navigator.pop(ctx);
          }),
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(AppSpace.l),
          child: AppGroup(children: [
            for (final f in s.failures)
              AppRow(
                leading: const LeadingIcon.danger(AppIcons.warning),
                title: [
                  offlineKindText(l, f.kind),
                  if (f.orderTitle != null) f.orderTitle!,
                ].join(' · '),
                subtitle: [
                  syncReasonText(l, f.reason),
                  if (f.photoKept) l.offPhotoKept,
                ].join('. '),
                subtitleMaxLines: 4,
              ),
          ]),
        ),
      ),
    ]),
  );
}

/// Тестовый режим (OFFLINE_TEST): переключатель «Сеть» для сквозного
/// сценария и показа в браузере. В рабочих сборках его нет.
class _TestSwitch extends StatelessWidget {
  const _TestSwitch({required this.service});
  final OfflineService service;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpace.l, vertical: AppSpace.xs),
        child: Row(children: [
          Text(context.l10n.offTestNet, style: AppText.footnote),
          const Spacer(),
          Switch.adaptive(
              key: const ValueKey('offline-test-net'),
              value: !service.forceOffline,
              onChanged: (v) => service.setForceOffline(!v)),
        ]),
      );
}
