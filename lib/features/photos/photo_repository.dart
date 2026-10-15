import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/schema_compat.dart';

/// Фото к заявке: «до» (от автора) или «после» (результат работы).
class WorkPhoto {
  final String id;
  final String stage; // before / after
  final String storagePath;
  final DateTime? takenAt;
  final double? lat;
  final double? lng;
  final bool mockLocation;
  final String? url; // временная ссылка на файл
  final String? uploaderName; // кто снял (profiles.full_name)

  /// Демо-история (шаг 24): путь `demo/<файл>` — нарисованная картинка из
  /// сборки (assets/demo_photos), а не файл в хранилище.
  final String? asset;

  /// Откуда снимок (0023): camera | file | telegram | demo; null — база без 0023.
  final String? source;

  /// Фото «после» загружено из файла — не доказательство (метка «из файла»).
  bool get fromFile => source == 'file';

  /// Шаг 27 (0024): снято без сети, насколько можно верить времени,
  /// когда дошло до сервера, расхождение часов, пометка «прислано после
  /// отмены», сверен ли отпечаток.
  final bool offline;
  final String? timeTrust;
  final DateTime? trustedAt;
  final DateTime? syncedAt;
  final int? driftS;
  final String? syncNote;
  final bool? sha256Ok;

  /// Шаг 28: снимок с телефона (предзагрузка для работы без сети) — когда
  /// ссылки на сервер нет.
  final Uint8List? bytes;

  const WorkPhoto(
      {required this.id,
      required this.stage,
      required this.storagePath,
      this.takenAt,
      this.lat,
      this.lng,
      this.mockLocation = false,
      this.url,
      this.uploaderName,
      this.asset,
      this.source,
      this.offline = false,
      this.timeTrust,
      this.trustedAt,
      this.syncedAt,
      this.driftS,
      this.syncNote,
      this.sha256Ok,
      this.bytes});

  bool get viewable => url != null || asset != null || bytes != null;

  /// Шаг 28: строка вложения из предзагрузки (без сети) + байты с телефона.
  factory WorkPhoto.offline(Map<String, dynamic> r, Uint8List? bytes) =>
      WorkPhoto(
        id: '${r['id']}',
        stage: (r['stage'] ?? 'before') as String,
        storagePath: '${r['storage_path'] ?? ''}',
        takenAt: DateTime.tryParse('${r['taken_at'] ?? ''}'),
        lat: (r['lat'] as num?)?.toDouble(),
        lng: (r['lng'] as num?)?.toDouble(),
        mockLocation: r['mock_location'] == true,
        asset: demoAsset('${r['storage_path'] ?? ''}'),
        bytes: bytes,
      );

  bool get hasLocation => lat != null && lng != null;

  /// Имя файла для «Скачать» / «Поделиться»: before_1791926088871.jpg.
  String get fileName => storagePath.split('/').last;
}

/// Снимок с камеры и метаданные, готовые к загрузке.
class CapturedPhoto {
  final Uint8List bytes;
  final DateTime takenAt;
  final double? lat;
  final double? lng;
  final bool mockLocation;

  /// camera — снято живой камерой приложения; file — выбран файл (0023).
  final String source;
  const CapturedPhoto(
      {required this.bytes,
      required this.takenAt,
      this.lat,
      this.lng,
      this.mockLocation = false,
      this.source = 'file'});

  CapturedPhoto withBytes(Uint8List b) => CapturedPhoto(
      bytes: b,
      takenAt: takenAt,
      lat: lat,
      lng: lng,
      mockLocation: mockLocation,
      source: source);
}

/// Путь демо-фото: `demo/ac_after.jpg` → `assets/demo_photos/ac_after.jpg`.
const demoPrefix = 'demo/';
String? demoAsset(String path) {
  if (!path.startsWith(demoPrefix)) return null;
  final name = path.substring(demoPrefix.length);
  return RegExp(r'^[a-z0-9_]+\.jpg$').hasMatch(name)
      ? 'assets/demo_photos/$name'
      : null;
}

class _NoPaths implements Exception {
  const _NoPaths();
}

class PhotoRepository {
  static const bucket = 'work-photos';
  final SupabaseClient _c = Supabase.instance.client;

  Future<List<WorkPhoto>> list(String workOrderId) async {
    Future<List<dynamic>> query(String extra) => _c
        .from('attachments')
        .select('id,stage,storage_path,taken_at,lat,lng,mock_location,$extra'
            'uploader:profiles!attachments_uploaded_by_fkey(full_name)')
        .eq('work_order_id', workOrderId)
        .eq('kind', 'photo')
        .order('created_at');
    final rows = await SchemaCompat.run(
        '0024',
        () => query('source,offline,time_trust,trusted_at,synced_at,'
            'time_drift_s,sync_note,sha256_ok,'),
        legacy: () => SchemaCompat.run('0023', () => query('source,'),
            legacy: () => query('')));
    final list = rows.cast<Map<String, dynamic>>();
    if (list.isEmpty) return const [];
    final paths = [
      for (final r in list)
        if (!(r['storage_path'] as String).startsWith(demoPrefix))
          r['storage_path'] as String
    ];
    final urls = <String, String>{};
    try {
      if (paths.isEmpty) throw const _NoPaths();
      final signed =
          await _c.storage.from(bucket).createSignedUrlsResult(paths, 60 * 60);
      for (final s in signed) {
        if (s is SignedUrlSuccess) urls[s.path] = s.signedUrl;
      }
    } catch (_) {
      // Без ссылок покажем заглушки вместо картинок.
    }
    return [
      for (final r in list)
        WorkPhoto(
          id: r['id'] as String,
          stage: (r['stage'] ?? 'after') as String,
          storagePath: r['storage_path'] as String,
          takenAt: DateTime.tryParse('${r['taken_at']}'),
          lat: (r['lat'] as num?)?.toDouble(),
          lng: (r['lng'] as num?)?.toDouble(),
          mockLocation: r['mock_location'] == true,
          url: urls[r['storage_path']],
          uploaderName:
              (r['uploader'] as Map<String, dynamic>?)?['full_name'] as String?,
          asset: demoAsset(r['storage_path'] as String),
          source: r['source'] as String?,
          offline: r['offline'] == true,
          timeTrust: r['time_trust'] as String?,
          trustedAt: DateTime.tryParse('${r['trusted_at'] ?? ''}'),
          syncedAt: DateTime.tryParse('${r['synced_at'] ?? ''}'),
          driftS: (r['time_drift_s'] as num?)?.toInt(),
          syncNote: r['sync_note'] as String?,
          sha256Ok: r['sha256_ok'] as bool?,
        ),
    ];
  }

  /// Байты файла — для «Поделиться» на телефоне.
  Future<Uint8List> download(String path) =>
      _c.storage.from(bucket).download(path);

  /// Загружает снимок в Storage и записывает его во вложения заявки.
  /// Путь <company_id>/<work_order_id>/<стадия>_<время>.jpg — по нему
  /// проверяются права в базе (миграция 0006).
  Future<void> upload(
      {required String companyId,
      required String workOrderId,
      required String stage,
      required CapturedPhoto photo}) async {
    final path =
        '$companyId/$workOrderId/${stage}_${photo.takenAt.millisecondsSinceEpoch}.jpg';
    await _c.storage.from(bucket).uploadBinary(path, photo.bytes,
        fileOptions:
            const FileOptions(contentType: 'image/jpeg', upsert: false));
    final row = {
      'work_order_id': workOrderId,
      'kind': 'photo',
      'stage': stage,
      'storage_path': path,
      'taken_at': photo.takenAt.toUtc().toIso8601String(),
      'lat': photo.lat,
      'lng': photo.lng,
      'mock_location': photo.mockLocation,
      'uploaded_by': _c.auth.currentUser?.id,
    };
    try {
      // Источник снимка (0023) ставится один раз, при вставке.
      await SchemaCompat.run('0023',
          () => _c.from('attachments').insert({...row, 'source': photo.source}),
          legacy: () => _c.from('attachments').insert(row));
    } catch (_) {
      // Запись не создалась — убираем «осиротевший» файл.
      try {
        await _c.storage.from(bucket).remove([path]);
      } catch (_) {}
      rethrow;
    }
  }
}
