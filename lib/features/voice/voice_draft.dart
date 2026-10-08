/// Черновик заявки, разобранный из голоса (или из набранного текста). Заявку из него создаёт
/// только пользователь — после проверки на экране подтверждения.
class VoiceDraft {
  final String transcript;
  final String title;
  final String? description;

  /// Слой (вид работ): id из layers — так возвращает серверная функция;
  /// либо название на любом языке. Приложение принимает его, только если
  /// такой слой есть у компании.
  final String? layerId;
  final String? layer;

  /// Как пользователь назвал место («переговорной, на третьем этаже»).
  final String? locationHint;

  /// Помещение и объект из справочника, если их удалось узнать по тексту.
  final String? locationId;
  final String? objectId;

  /// low / normal / high / critical — как в work_orders.priority.
  final String priority;

  const VoiceDraft({
    required this.transcript,
    required this.title,
    this.description,
    this.layerId,
    this.layer,
    this.locationHint,
    this.locationId,
    this.objectId,
    this.priority = 'normal',
  });

  static const priorities = {'low', 'normal', 'high', 'critical'};

  factory VoiceDraft.fromJson(Map<String, dynamic> m) {
    final p = m['priority'] as String?;
    return VoiceDraft(
      transcript: (m['transcript'] ?? '') as String,
      title: (m['title'] ?? '') as String,
      description: m['description'] as String?,
      layerId: m['layer_id'] as String?,
      layer: m['layer'] as String?,
      locationHint: m['location_hint'] as String?,
      locationId: m['location_id'] as String?,
      objectId: m['object_id'] as String?,
      priority: priorities.contains(p) ? p! : 'normal',
    );
  }
}
