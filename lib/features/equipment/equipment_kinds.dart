import 'package:flutter/widgets.dart';

import '../../core/design/design.dart';
import '../../l10n/app_localizations.dart';
import '../directory/directory.dart';

/// Вид оборудования (assets.meta.kind) — каталог шага 22.
///
/// Та же таблица — в `supabase/functions/_shared/kinds.ts` (по ней модель
/// выбирает вид на фото); подписи — ключи `eqKind_<код>` в `lib/l10n/*.arb`.
/// Совпадение кодов, систем и подписей проверяет
/// `test/equipment_kinds_test.dart`.
class EquipmentKind {
  const EquipmentKind(this.code, this.layerEn, this.icon);

  final String code;

  /// Система по умолчанию — английское название слоя (`layers.name_i18n.en`,
  /// как в `seed_default_layers`); null — не очевидна.
  final String? layerEn;
  final IconData icon;
}

const kEquipmentKinds = <EquipmentKind>[
  EquipmentKind('ac', 'HVAC', AppIcons.eqAirCon),
  EquipmentKind('ac_outdoor', 'HVAC', AppIcons.eqAcOutdoor),
  EquipmentKind('fancoil', 'HVAC', AppIcons.eqFan),
  EquipmentKind('vent_grille', 'HVAC', AppIcons.eqVent),
  EquipmentKind('radiator', 'HVAC', AppIcons.eqRadiator),
  EquipmentKind('sensor', 'HVAC', AppIcons.eqSensor),
  EquipmentKind('panel', 'Electrical', AppIcons.eqPanel),
  EquipmentKind('light', 'Electrical', AppIcons.eqLight),
  EquipmentKind('socket', 'Electrical', AppIcons.eqSocket),
  EquipmentKind('ups', 'Electrical', AppIcons.eqUps),
  EquipmentKind('server', 'Electrical', AppIcons.eqServer),
  EquipmentKind('smoke', 'Security systems', AppIcons.eqSmoke),
  EquipmentKind('extinguisher', 'Security systems', AppIcons.eqExtinguisher),
  EquipmentKind('camera', 'Security systems', AppIcons.eqCamera),
  EquipmentKind('access_reader', 'Security systems', AppIcons.eqAccessReader),
  EquipmentKind('door_lock', 'Security systems', AppIcons.eqLock),
  EquipmentKind('faucet', 'Plumbing', AppIcons.eqFaucet),
  EquipmentKind('toilet', 'Plumbing', AppIcons.eqToilet),
  EquipmentKind('water_heater', 'Plumbing', AppIcons.eqWaterHeater),
  EquipmentKind('water', 'Plumbing', AppIcons.eqWater),
  EquipmentKind('lift_panel', 'Other', AppIcons.eqLift),
  EquipmentKind('other', null, AppIcons.eqOther),
];

/// Старые коды из данных до шага 22 → код каталога.
const kEquipmentKindAliases = {
  'vent': 'vent_grille',
  'lift': 'lift_panel',
  'generator': 'panel',
};

/// Код каталога по коду (или старому коду), иначе null.
EquipmentKind? equipmentKind(String? code) {
  if (code == null) return null;
  final c = code.trim().toLowerCase();
  final k = kEquipmentKindAliases[c] ?? c;
  for (final e in kEquipmentKinds) {
    if (e.code == k) return e;
  }
  return null;
}

/// Подпись вида на языке интерфейса.
String equipmentKindLabel(AppLocalizations l, String code) =>
    switch (equipmentKind(code)?.code ?? 'other') {
      'ac' => l.eqKind_ac,
      'ac_outdoor' => l.eqKind_ac_outdoor,
      'fancoil' => l.eqKind_fancoil,
      'vent_grille' => l.eqKind_vent_grille,
      'radiator' => l.eqKind_radiator,
      'sensor' => l.eqKind_sensor,
      'panel' => l.eqKind_panel,
      'light' => l.eqKind_light,
      'socket' => l.eqKind_socket,
      'ups' => l.eqKind_ups,
      'server' => l.eqKind_server,
      'smoke' => l.eqKind_smoke,
      'extinguisher' => l.eqKind_extinguisher,
      'camera' => l.eqKind_camera,
      'access_reader' => l.eqKind_access_reader,
      'door_lock' => l.eqKind_door_lock,
      'faucet' => l.eqKind_faucet,
      'toilet' => l.eqKind_toilet,
      'water_heater' => l.eqKind_water_heater,
      'water' => l.eqKind_water,
      'lift_panel' => l.eqKind_lift_panel,
      _ => l.eqKind_other,
    };

/// Вид по коду или подписи на любом языке (импорт из Excel: колонка «Вид»).
/// [labels] — подписи RU и EN (из обоих `AppLocalizations`). Не найден — null.
String? kindFromText(String? text, Iterable<AppLocalizations> labels) {
  final t = _norm(text);
  if (t.isEmpty) return null;
  final byCode = equipmentKind(t);
  if (byCode != null) return byCode.code;
  for (final l in labels) {
    for (final k in kEquipmentKinds) {
      if (_norm(equipmentKindLabel(l, k.code)) == t) return k.code;
    }
  }
  return null;
}

String _norm(String? s) => (s ?? '').trim().toLowerCase().replaceAll('ё', 'е');

/// Система вида по умолчанию среди слоёв компании (по английскому названию).
Layer? defaultLayerForKind(String? code, List<Layer> layers) {
  final en = equipmentKind(code)?.layerEn;
  if (en == null) return null;
  for (final y in layers) {
    if (y.label('en').toLowerCase() == en.toLowerCase()) return y;
  }
  return null;
}

/// Значок оборудования по виду (assets.meta.kind, каталог
/// [kEquipmentKinds]), иначе по категории — те же значки, что у маркеров на
/// плане (floors/plan_canvas.dart).
IconData assetIcon(String? kind, String category) {
  final k = equipmentKind(kind);
  if (k != null && k.code != 'other') return k.icon;
  return switch (category) {
    'furniture' => AppIcons.eqFurniture,
    'infra' => AppIcons.eqInfra,
    'other' => AppIcons.eqOther,
    _ => AppIcons.wrench,
  };
}
