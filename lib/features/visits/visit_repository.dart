import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Посещение объекта исполнителем по заявке (таблица visits, миграция 0009).
/// Время, расстояние до объекта и флаг геозоны считает база.
class Visit {
  final String id;
  final String profileId;
  final String? personName;
  final DateTime startedAt;
  final DateTime? endedAt;

  /// true — в геозоне, false — вне её, null — проверить не удалось.
  final bool? inGeofence;
  final double? distanceM;
  final bool mockLocation;

  const Visit(
      {required this.id,
      required this.profileId,
      this.personName,
      required this.startedAt,
      this.endedAt,
      this.inGeofence,
      this.distanceM,
      this.mockLocation = false});

  /// Нужно ли предупредить менеджера.
  bool get suspicious => inGeofence == false || mockLocation;

  factory Visit.fromMap(Map<String, dynamic> m) => Visit(
        id: m['id'] as String,
        profileId: m['profile_id'] as String,
        personName:
            (m['profiles'] as Map<String, dynamic>?)?['full_name'] as String?,
        startedAt: DateTime.parse('${m['started_at']}'),
        endedAt: DateTime.tryParse('${m['ended_at']}'),
        inGeofence: m['in_geofence'] as bool?,
        distanceM: (m['distance_m'] as num?)?.toDouble(),
        mockLocation: m['mock_location'] == true,
      );
}

class VisitRepository {
  final SupabaseClient _c = Supabase.instance.client;

  /// Посещения по заявке. Менеджер видит все, остальные — только свои (RLS).
  Future<List<Visit>> list(String workOrderId) async {
    final rows = await _c
        .from('visits')
        .select(
            'id,profile_id,started_at,ended_at,in_geofence,distance_m,mock_location,profiles(full_name)')
        .eq('work_order_id', workOrderId)
        .order('started_at');
    return (rows as List)
        .map((e) => Visit.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Отмечает начало посещения. Компанию, объект и время база берёт сама;
  /// время окончания она ставит, когда заявка выходит из «в работе».
  Future<void> start(
      {required String workOrderId,
      required String companyId,
      Position? position}) async {
    await _c.from('visits').insert({
      'work_order_id': workOrderId,
      'company_id': companyId,
      'profile_id': _c.auth.currentUser?.id,
      'lat': position?.latitude,
      'lng': position?.longitude,
      'accuracy_m': position?.accuracy,
      'mock_location': position?.isMocked ?? false,
    });
  }
}
