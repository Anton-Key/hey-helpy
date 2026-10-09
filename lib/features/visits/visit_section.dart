import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../l10n/app_localizations.dart';
import 'visit_repository.dart';

/// Блок «Посещения» в карточке заявки (для менеджера):
/// «На объекте 14:05–14:47, в геозоне ✓» или «вне геозоны ⚠».
class VisitsSection extends StatelessWidget {
  const VisitsSection(
      {super.key, required this.visits, required this.loadFailed});

  final List<Visit> visits;
  final bool loadFailed;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (loadFailed) {
      return AppGroup(header: l.visitsTitle, children: [
        AppRow(
            title: l.visitsLoadFailed,
            titleStyle: AppText.callout.copyWith(color: AppColors.danger)),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(l.visitsTitle),
      if (visits.any((v) => v.suspicious))
        Container(
          margin: const EdgeInsetsDirectional.only(bottom: AppSpace.s),
          padding: const EdgeInsets.all(AppSpace.m),
          decoration: BoxDecoration(
              color: AppColors.dangerTint,
              borderRadius: BorderRadius.circular(AppRadius.group)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(AppIcons.warning,
                color: AppColors.danger, size: AppSizes.icon),
            const SizedBox(width: AppSpace.s),
            Expanded(
                child: Text(l.visitOutsideWarning,
                    style: AppText.footnote.copyWith(
                        color: AppColors.danger, fontWeight: FontWeight.w600))),
          ]),
        ),
      AppGroup(children: [for (final v in visits) _VisitTile(visit: v)]),
    ]);
  }
}

class _VisitTile extends StatelessWidget {
  const _VisitTile({required this.visit});
  final Visit visit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = visit;
    final geoText = switch (v.inGeofence) {
      true => l.visitInGeofence,
      false => l.visitOutsideGeofence,
      null => l.visitGeofenceUnknown,
    };
    final geoColor = switch (v.inGeofence) {
      true => AppColors.accentText,
      false => AppColors.danger,
      null => AppColors.secondary,
    };
    final details = [
      if (v.inGeofence == false && v.distanceM != null)
        l.visitDistance(NumberFormat.decimalPattern(l.localeName)
            .format(v.distanceM!.round())),
      if (v.mockLocation) l.visitMockLocation,
    ];
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpace.rowH, vertical: AppSpace.rowV),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LeadingIcon(
              v.inGeofence == false ? AppIcons.placeOff : AppIcons.place,
              color: geoColor,
              background: v.inGeofence == false
                  ? AppColors.dangerTint
                  : AppColors.accentTint),
          const SizedBox(width: AppSpace.m),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (v.personName?.isNotEmpty == true)
                Text(v.personName!, style: AppText.footnote),
              Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${_range(l, v)}, '),
                    TextSpan(
                        text: geoText,
                        style: TextStyle(
                            color: geoColor, fontWeight: FontWeight.w600)),
                  ]),
                  style: AppText.rowTitle),
              for (final d in details)
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 2),
                  child: Text(d,
                      style:
                          AppText.footnote.copyWith(color: AppColors.danger)),
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  /// «На объекте 14:05–14:47»; дата — только если посещение не сегодня.
  static String _range(AppLocalizations l, Visit v) {
    final start = v.startedAt.toLocal();
    final now = DateTime.now();
    final today = start.year == now.year &&
        start.month == now.month &&
        start.day == now.day;
    final time = DateFormat.Hm(l.localeName);
    final from = today
        ? time.format(start)
        : '${DateFormat.MMMd(l.localeName).format(start)}, ${time.format(start)}';
    final end = v.endedAt?.toLocal();
    if (end == null) return l.visitOnSiteSince(from);
    return l.visitOnSiteRange(from, time.format(end));
  }
}
