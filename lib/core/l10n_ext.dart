import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/user_role.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String get localeCode => Localizations.localeOf(this).languageCode;
}

/// Подписи для кодов, которые хранятся в базе (статусы, срочность, роли).
extension L10nCodes on AppLocalizations {
  String status(String code) => switch (code) {
        'new' => statusNew,
        'assigned' => statusAssigned,
        'in_progress' => statusInProgress,
        'on_review' => statusOnReview,
        'returned' => statusReturned,
        'done' => statusDone,
        'cancelled' => statusCancelled,
        'overdue' => statusOverdue,
        _ => code,
      };

  String priority(String code) => switch (code) {
        'low' => priorityLow,
        'normal' => priorityNormal,
        'high' => priorityHigh,
        'critical' => priorityCritical,
        _ => code,
      };

  String objectType(String code) => switch (code) {
        'office' => objectTypeOffice,
        'hotel' => objectTypeHotel,
        'apartments' => objectTypeApartments,
        'warehouse' => objectTypeWarehouse,
        _ => objectTypeOther,
      };

  String role(UserRole r) => switch (r) {
        UserRole.admin => roleAdmin,
        UserRole.manager => roleManager,
        UserRole.requester => roleRequester,
        UserRole.contractor => roleContractor,
        UserRole.executor => roleExecutor,
      };

  /// Понятный текст для ошибок, которые возвращает база при смене статуса.
  String statusError(Object e) {
    final m = '$e';
    if (m.contains('photo required')) return errPhotoRequired;
    if (m.contains('return reason required')) return returnReasonRequired;
    if (m.contains('not allowed')) return errNotAllowed;
    return errorGeneric;
  }

  /// Длительность: «45 мин», «2 ч 5 мин», «3 д 4 ч».
  String duration(Duration d) {
    final n = NumberFormat.decimalPattern(localeName);
    final minutes = d.inMinutes;
    if (minutes < 60) return durationMinutes(n.format(minutes));
    if (d.inHours < 24) {
      return durationHoursMinutes(n.format(d.inHours), n.format(minutes % 60));
    }
    return durationDaysHours(n.format(d.inDays), n.format(d.inHours % 24));
  }

  /// Дата и время по правилам выбранного языка.
  String dateTime(DateTime d) =>
      DateFormat.yMMMd(localeName).add_Hm().format(d.toLocal());

  /// Только дата («10 окт. 2026 г.»). Даты без времени (UTC-полночь) — как есть.
  String date(DateTime d) => DateFormat.yMMMd(localeName)
      .format(d.isUtc && d.hour == 0 && d.minute == 0 ? d : d.toLocal());
}
