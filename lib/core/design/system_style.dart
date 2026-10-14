import 'package:flutter/widgets.dart';

import 'icons.dart';

/// Цвета и значки систем (слоёв) — шаг 24, миграция 0020.
/// В базе хранятся строкой: цвет «#RRGGBB», значок — код из [kSystemIcons].
class SystemPalette {
  const SystemPalette._();

  /// 8 цветов для выбора; первые шесть — цвета систем по умолчанию (0004).
  static const colors = <String>[
    '#0E8C80', // климат
    '#C27A0A', // электрика
    '#2F6FE0', // сантехника
    '#7A55C7', // клининг
    '#8A6A4F', // мебель
    '#5E6D7C', // другое
    '#B42318', // безопасность
    '#3B4A6B',
  ];

  static const fallback = Color(0xFF5E6D7C);

  /// «#0E8C80» → цвет; кривая строка — серый.
  static Color parse(String? hex) {
    final h = (hex ?? '').replaceFirst('#', '');
    if (h.length != 6) return fallback;
    final v = int.tryParse(h, radix: 16);
    return v == null ? fallback : Color(0xFF000000 | v);
  }
}

/// Коды значков систем → значок. Новый код — сюда (и только латиница,
/// как проверяет база: `^[a-z][a-z0-9_]{0,23}$`).
const kSystemIcons = <String, IconData>{
  'climate': AppIcons.eqAirCon,
  'electric': AppIcons.eqPanel,
  'plumbing': AppIcons.eqWater,
  'cleaning': AppIcons.sparkles,
  'furniture': AppIcons.eqFurniture,
  'security': AppIcons.eqSmoke,
  'fire': AppIcons.eqExtinguisher,
  'access': AppIcons.eqLock,
  'lift': AppIcons.eqLift,
  'light': AppIcons.eqLight,
  'it': AppIcons.eqServer,
  'other': AppIcons.wrench,
};

/// Значок системы: по коду, иначе по названию стандартной системы, иначе ключ.
String systemIconCode(String? code, String name) {
  if (code != null && kSystemIcons.containsKey(code)) return code;
  final n = name.toLowerCase();
  if (n.contains('климат') || n.contains('hvac') || n.contains('climate')) {
    return 'climate';
  }
  if (n.contains('электр') || n.contains('electr')) return 'electric';
  if (n.contains('сантех') || n.contains('plumb')) return 'plumbing';
  if (n.contains('клин') || n.contains('clean')) return 'cleaning';
  if (n.contains('мебел') || n.contains('furnit')) return 'furniture';
  if (n.contains('безопас') || n.contains('secur')) return 'security';
  if (n.contains('лифт') || n.contains('lift')) return 'lift';
  return 'other';
}

IconData systemIcon(String? code, String name) =>
    kSystemIcons[systemIconCode(code, name)]!;
