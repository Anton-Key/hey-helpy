import 'package:latlong2/latlong.dart';

import '../directory/directory.dart';

/// Откуда открыли форму новой заявки — подпись под полем «Объект».
enum PlaceOrigin { objectCard, map, plan, equipment, photo, camera, order }

/// Откуда взялся объект в форме: контекст, GPS или никак (пусто).
enum PlaceSource { context, gps, none }

/// Ближе этого объект считается «рядом с вами» (шаг 24).
const kNearbyRadiusM = 200;

/// Сколько недавних объектов предлагать кнопками.
const kRecentObjects = 3;

class NearbyObject {
  const NearbyObject(this.object, this.distanceM);
  final Obj object;
  final int distanceM;
}

/// Ближайший видимый пользователю объект с координатами не дальше
/// [radiusM] от точки, иначе null.
NearbyObject? nearestObject(List<Obj> objects, double lat, double lng,
    {int radiusM = kNearbyRadiusM}) {
  const dist = Distance();
  final here = LatLng(lat, lng);
  NearbyObject? best;
  for (final o in objects) {
    if (o.lat == null || o.lng == null) continue;
    final d = dist.as(LengthUnit.Meter, here, LatLng(o.lat!, o.lng!)).round();
    if (d > radiusM) continue;
    if (best == null || d < best.distanceM) best = NearbyObject(o, d);
  }
  return best;
}

/// До [max] разных объектов из заявок пользователя (новые — первыми),
/// только из тех, что ему видны.
List<Obj> recentObjects(List<String?> objectIdsNewestFirst, List<Obj> objects,
    {int max = kRecentObjects}) {
  final byId = {for (final o in objects) o.id: o};
  final out = <Obj>[];
  for (final id in objectIdsNewestFirst) {
    final o = byId[id];
    if (o == null || out.contains(o)) continue;
    out.add(o);
    if (out.length == max) break;
  }
  return out;
}

class InitialPlace {
  const InitialPlace(
      {this.objectId,
      this.locationId,
      this.source = PlaceSource.none,
      this.origin,
      this.distanceM});
  final String? objectId;
  final String? locationId;
  final PlaceSource source;
  final PlaceOrigin? origin;
  final int? distanceM;

  static const empty = InitialPlace();
}

/// Место новой заявки по порядку (шаг 24):
/// 1) контекст, откуда открыли форму — объект и, если есть, помещение;
/// 2) иначе ближайший объект по GPS ≤ 200 м — **без помещения**;
/// 3) иначе пусто. Прошлая заявка в расчёт не входит никогда.
InitialPlace initialOrderPlace({
  required List<Obj> objects,
  String? contextObjectId,
  String? contextLocationId,
  PlaceOrigin? origin,
  NearbyObject? nearby,
}) {
  if (contextObjectId != null && objects.any((o) => o.id == contextObjectId)) {
    return InitialPlace(
        objectId: contextObjectId,
        locationId: contextLocationId,
        source: PlaceSource.context,
        origin: origin);
  }
  if (nearby != null &&
      nearby.distanceM <= kNearbyRadiusM &&
      objects.any((o) => o.id == nearby.object.id)) {
    return InitialPlace(
        objectId: nearby.object.id,
        source: PlaceSource.gps,
        distanceM: nearby.distanceM);
  }
  return InitialPlace.empty;
}
