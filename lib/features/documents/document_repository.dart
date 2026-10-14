import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/schema_compat.dart';
import '../photo_identify/identify_log.dart' show newUuid;
import 'document_logic.dart';

/// Документ заявки (attachments.kind = 'document', миграция 0019).
class OrderDocument {
  const OrderDocument({
    required this.id,
    required this.fileName,
    required this.mime,
    required this.sizeBytes,
    required this.storagePath,
    this.uploadedBy,
    this.uploaderName,
    this.createdAt,
  });
  final String id;
  final String fileName;
  final String mime;
  final int sizeBytes;
  final String storagePath;
  final String? uploadedBy;
  final String? uploaderName;
  final DateTime? createdAt;

  DocKind get kind => docKindOf(fileName, mime);
}

/// Файл, выбранный, но ещё не загруженный (форма новой заявки).
class PickedDocument {
  const PickedDocument(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

class DocumentRepository {
  static const bucket = 'order-files';
  final SupabaseClient _c = Supabase.instance.client;

  /// Документы заявки; без 0019 — пусто (MigrationMissing ловит экран).
  Future<List<OrderDocument>> list(String workOrderId) =>
      SchemaCompat.run('0019', () async {
        final rows = await _c
            .from('attachments')
            .select('id,file_name,mime,size_bytes,storage_path,uploaded_by,'
                'created_at,uploader:profiles!attachments_uploaded_by_fkey(full_name)')
            .eq('work_order_id', workOrderId)
            .eq('kind', 'document')
            .order('created_at');
        return [
          for (final r in (rows as List).cast<Map<String, dynamic>>())
            OrderDocument(
              id: r['id'] as String,
              fileName: (r['file_name'] ?? '') as String,
              mime: (r['mime'] ?? '') as String,
              sizeBytes: (r['size_bytes'] as num?)?.toInt() ?? 0,
              storagePath: r['storage_path'] as String,
              uploadedBy: r['uploaded_by'] as String?,
              uploaderName: (r['uploader']
                  as Map<String, dynamic>?)?['full_name'] as String?,
              createdAt: DateTime.tryParse('${r['created_at']}'),
            ),
        ];
      }, legacy: () async => const []);

  /// Загрузить файл и записать его в документы заявки. Не вышло записать —
  /// файл убирается из хранилища.
  Future<void> upload(
      {required String companyId,
      required String workOrderId,
      required PickedDocument file}) async {
    final mime = mimeForName(file.name)!;
    final path = documentPath(companyId, workOrderId, newUuid(), file.name);
    await _c.storage.from(bucket).uploadBinary(path, file.bytes,
        fileOptions: FileOptions(contentType: mime, upsert: false));
    try {
      await _c.from('attachments').insert({
        'work_order_id': workOrderId,
        'kind': 'document',
        'storage_path': path,
        'file_name': displayFileName(file.name),
        'mime': mime,
        'size_bytes': file.bytes.length,
        'uploaded_by': _c.auth.currentUser?.id,
      });
    } catch (_) {
      try {
        await _c.storage.from(bucket).remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  /// Ссылка на час — открыть или скачать.
  Future<String> signedUrl(String path) =>
      _c.storage.from(bucket).createSignedUrl(path, 60 * 60);

  Future<Uint8List> download(String path) =>
      _c.storage.from(bucket).download(path);

  /// Удалить: сначала запись (её права проверяет база), потом файл.
  Future<void> delete(OrderDocument d) async {
    final gone =
        await _c.from('attachments').delete().eq('id', d.id).select('id');
    if ((gone as List).isEmpty) throw const DocumentDeleteDenied();
    try {
      await _c.storage.from(bucket).remove([d.storagePath]);
    } catch (e) {
      debugPrint('document file: ${e.runtimeType}');
    }
  }
}

class DocumentDeleteDenied implements Exception {
  const DocumentDeleteDenied();
}
