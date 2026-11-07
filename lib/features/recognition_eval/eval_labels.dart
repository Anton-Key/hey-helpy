import '../../l10n/app_localizations.dart';

/// Подписи условий съёмки и разбивок теста распознавания (шаг 34).
String Function(String) evalLightLabel(AppLocalizations l) =>
    (v) => switch (v) {
          'dim' => l.evalLight_dim,
          'backlight' => l.evalLight_backlight,
          _ => l.evalLight_good,
        };

String Function(String) evalDistanceLabel(AppLocalizations l) =>
    (v) => switch (v) {
          'close' => l.evalDistance_close,
          'far' => l.evalDistance_far,
          _ => l.evalDistance_medium,
        };

String Function(String) evalAngleLabel(AppLocalizations l) =>
    (v) => switch (v) {
          'side' => l.evalAngle_side,
          _ => l.evalAngle_front,
        };

/// Подписи условий съёмки — и для списка фото и отчёта.
String evalConditionLabel(AppLocalizations l, String group, String v) =>
    switch (group) {
      'light' => evalLightLabel(l)(v),
      'distance' => evalDistanceLabel(l)(v),
      'angle' => evalAngleLabel(l)(v),
      'occlusion' => v == 'yes' ? l.evalOcclusion_yes : l.evalOcclusion_no,
      'similar' => v == 'several_similar'
          ? l.evalSimilar_several_similar
          : l.evalSimilar_single,
      _ => v,
    };
