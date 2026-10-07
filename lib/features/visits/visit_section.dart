import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/l10n_ext.dart';
import '../../l10n/app_localizations.dart';
import 'visit_repository.dart';

const _ink = Color(0xFF1C1E22);
const _muted = Color(0xFF8A9098);
const _line = Color(0xFFE8EAED);
const _ok = Color(0xFF177A65);
const _danger = Color(0xFFC24444);

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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.visitsTitle,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
      const SizedBox(height: 10),
      if (loadFailed)
        Text(l.visitsLoadFailed, style: const TextStyle(color: _danger))
      else ...[
        if (visits.any((v) => v.suspicious))
          Container(
            margin: const EdgeInsetsDirectional.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFFFBE8E8),
                borderRadius: BorderRadius.circular(14)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.warning_amber_rounded, color: _danger, size: 20),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(l.visitOutsideWarning,
                      style: const TextStyle(
                          color: _danger,
                          fontWeight: FontWeight.w600,
                          fontSize: 13))),
            ]),
          ),
        for (final v in visits) _VisitTile(visit: v),
      ],
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
    final geoColor =
        switch (v.inGeofence) { true => _ok, false => _danger, null => _muted };
    final details = [
      if (v.inGeofence == false && v.distanceM != null)
        l.visitDistance(NumberFormat.decimalPattern(l.localeName)
            .format(v.distanceM!.round())),
      if (v.mockLocation) l.visitMockLocation,
    ];
    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (v.personName?.isNotEmpty == true)
          Text(v.personName!,
              style: const TextStyle(
                  color: _muted, fontSize: 12, fontWeight: FontWeight.w600)),
        Text.rich(
            TextSpan(children: [
              TextSpan(text: '${_range(l, v)}, '),
              TextSpan(
                  text: geoText,
                  style:
                      TextStyle(color: geoColor, fontWeight: FontWeight.w800)),
            ]),
            style: const TextStyle(
                color: _ink, fontSize: 14, fontWeight: FontWeight.w600)),
        for (final d in details)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 4),
            child:
                Text(d, style: const TextStyle(color: _danger, fontSize: 13)),
          ),
      ]),
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
