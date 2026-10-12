import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../floors/floor_models.dart';
import '../voice/speech_input.dart' show voiceMock;
import 'identify_models.dart';
import 'photo_compress.dart';

/// Почему не получилось узнать: показываем простыми словами и всегда даём
/// выбрать оборудование вручную.
enum IdentifyProblem { failed, tooLarge, offline }

class IdentifyException implements Exception {
  const IdentifyException(this.problem);
  final IdentifyProblem problem;
  @override
  String toString() => 'IdentifyException($problem)';
}

/// Где человек (что известно): помещение → этаж → объект.
class IdentifyPlace {
  const IdentifyPlace(
      {this.objectId, this.floorId, this.locationId, this.orderId});
  final String? objectId;
  final String? floorId;
  final String? locationId;
  final String? orderId;
}

typedef IdentifyCall = Future<Object?> Function(Map<String, dynamic> body);

/// Снимок → [PhotoIdentification] через Edge Function `photo-identify`
/// (мультимодальная модель Yandex AI Studio, сопоставление с реестром — на
/// сервере, под RLS пользователя).
///
/// С `--dart-define=VOICE_MOCK=true` (снимки `/screens`, сквозные тесты) —
/// заглушка без сети: «кондиционер, 91 %», кандидаты — из реестра объекта
/// по виду и месту ([mockCandidates]).
class PhotoIdentifyClient {
  PhotoIdentifyClient({IdentifyCall? call, this.timeout = defaultTimeout})
      : _call = call ?? _invoke;

  static const functionName = 'photo-identify';

  /// Функции нужно до 14 с на модель плюс вход и справочники.
  static const defaultTimeout = Duration(seconds: 16);

  final IdentifyCall _call;
  final Duration timeout;

  static Future<Object?> _invoke(Map<String, dynamic> body) async {
    try {
      final res = await Supabase.instance.client.functions
          .invoke(functionName, body: body);
      return res.data;
    } on FunctionException catch (e) {
      final d = e.details;
      if (e.status == 400 && d is Map && d['error'] == 'too_large') {
        throw const IdentifyException(IdentifyProblem.tooLarge);
      }
      debugPrint('photo-identify: HTTP ${e.status}');
      throw const IdentifyException(IdentifyProblem.failed);
    }
  }

  /// Тело запроса: base64 снимка, язык и место (только известные id).
  static Map<String, dynamic> body(
          Uint8List jpeg, String locale, IdentifyPlace place) =>
      {
        'image': base64Encode(jpeg),
        'locale': locale == 'ru' ? 'ru' : 'en',
        if (place.objectId != null) 'objectId': place.objectId,
        if (place.floorId != null) 'floorId': place.floorId,
        if (place.locationId != null) 'locationId': place.locationId,
        if (place.orderId != null) 'orderId': place.orderId,
      };

  Future<PhotoIdentification> identify(Uint8List jpeg,
      {required String locale, required IdentifyPlace place}) async {
    if (jpeg.length > kIdentifyMaxBytes) {
      throw const IdentifyException(IdentifyProblem.tooLarge);
    }
    Object? data;
    try {
      data = await _call(body(jpeg, locale, place)).timeout(timeout);
    } on IdentifyException {
      rethrow;
    } on TimeoutException {
      throw const IdentifyException(IdentifyProblem.failed);
    } catch (e) {
      debugPrint('photo-identify: ${e.runtimeType}');
      throw const IdentifyException(IdentifyProblem.offline);
    }
    final r = PhotoIdentification.fromJson(data);
    if (r == null) throw const IdentifyException(IdentifyProblem.failed);
    return r;
  }
}

/// Заглушка для `/screens` и сквозных тестов: без сети и модели.
class MockPhotoIdentify {
  const MockPhotoIdentify();

  Future<PhotoIdentification> identify(
      {required List<PlanItem> items,
      required Map<String, String> floorNames,
      required IdentifyPlace place,
      String? hvacLayerId,
      String? hvacLayerName}) async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    return PhotoIdentification(
      kind: 'ac',
      layerId: hvacLayerId,
      layerName: hvacLayerName,
      confidence: 0.91,
      candidates: mockCandidates('ac', items, floorNames, place),
      model: 'main',
      ms: 1200,
    );
  }
}

bool get photoIdentifyMock => voiceMock;

/// Кандидаты по виду и месту — упрощённое повторение сопоставления функции
/// (`_shared/identify.ts`, `matchCandidates`) для заглушки: тот же вид, затем
/// то же помещение → тот же этаж → объект. До 3.
List<IdentifyCandidate> mockCandidates(String kind, List<PlanItem> items,
    Map<String, String> floorNames, IdentifyPlace place) {
  final places = {
    for (final i in items)
      if (i.isPlace) i.id: i
  };
  final scored = <(int, IdentifyCandidate)>[];
  for (final a in items) {
    if (a.isPlace || a.equipmentKind != kind) continue;
    final room = places[a.locationId];
    final floorId = a.floorId ?? room?.floorId;
    final reasons = <String>['kind'];
    var pts = 35;
    if (place.locationId != null && a.locationId == place.locationId) {
      reasons.add('same_room');
      pts += 30;
    } else if (place.floorId != null && floorId == place.floorId) {
      reasons.add('same_floor');
      pts += 12;
    } else if (place.objectId != null) {
      reasons.add('same_object');
      pts += 5;
    }
    scored.add((
      pts,
      IdentifyCandidate(
        assetId: a.id,
        name: a.name,
        locationId: a.locationId ?? '',
        locationLabel: room == null
            ? ''
            : [room.code, room.name]
                .whereType<String>()
                .where((s) => s.trim().isNotEmpty)
                .join(' '),
        floorLabel: floorId == null ? null : floorNames[floorId],
        score: pts / 100,
        reasons: reasons,
      )
    ));
  }
  scored.sort((x, y) =>
      y.$1 != x.$1 ? y.$1.compareTo(x.$1) : x.$2.name.compareTo(y.$2.name));
  return [for (final s in scored.take(3)) s.$2];
}
