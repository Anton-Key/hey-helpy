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

  /// Дата и время по правилам выбранного языка.
  String dateTime(DateTime d) => DateFormat.yMMMd(localeName).add_Hm().format(d.toLocal());
}
