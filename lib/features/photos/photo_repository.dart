import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

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

  const WorkPhoto({required this.id, required this.stage, required this.storagePath,
      this.takenAt, this.lat, this.lng, this.mockLocation = false, this.url});

  bool get hasLocation => lat != null && lng != null;
}

/// Снимок с камеры и метаданные, готовые к загрузке.
class CapturedPhoto {
  final Uint8List bytes;
  final DateTime takenAt;
  final double? lat;
  final double? lng;
  final bool mockLocation;
  const CapturedPhoto({required this.bytes, required this.takenAt, this.lat, this.lng, this.mockLocation = false});
}

class PhotoRepository {
  static const bucket = 'work-photos';
  final SupabaseClient _c = Supabase.instance.client;

  Future<List<WorkPhoto>> list(String workOrderId) async {
    final rows = await _c
        .from('attachments')
        .select('id,stage,storage_path,taken_at,lat,lng,mock_location')
        .eq('work_order_id', workOrderId)
        .eq('kind', 'photo')
        .order('created_at');
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return const [];
    final paths = [for (final r in list) r['storage_path'] as String];
    final urls = <String, String>{};
    try {
      final signed = await _c.storage.from(bucket).createSignedUrlsResult(paths, 60 * 60);
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
        ),
    ];
  }

  /// Загружает снимок в Storage и записывает его во вложения заявки.
  /// Путь <company_id>/<work_order_id>/<стадия>_<время>.jpg — по нему
  /// проверяются права в базе (миграция 0006).
  Future<void> upload({required String companyId, required String workOrderId,
      required String stage, required CapturedPhoto photo}) async {
    final path = '$companyId/$workOrderId/${stage}_${photo.takenAt.millisecondsSinceEpoch}.jpg';
    await _c.storage.from(bucket).uploadBinary(path, photo.bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false));
    try {
      await _c.from('attachments').insert({
        'work_order_id': workOrderId,
        'kind': 'photo',
        'stage': stage,
        'storage_path': path,
        'taken_at': photo.takenAt.toUtc().toIso8601String(),
        'lat': photo.lat,
        'lng': photo.lng,
        'mock_location': photo.mockLocation,
        'uploaded_by': _c.auth.currentUser?.id,
      });
    } catch (_) {
      // Запись не создалась — убираем «осиротевший» файл.
      try { await _c.storage.from(bucket).remove([path]); } catch (_) {}
      rethrow;
    }
  }
}
