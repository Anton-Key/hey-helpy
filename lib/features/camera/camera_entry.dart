import 'package:flutter/widgets.dart';

import '../../core/design/design.dart';
import '../photo_identify/photo_identify_screen.dart';
import 'camera_screen.dart';
import 'live_camera.dart';

/// «По фото» (шаг 25): открывает «Камеру-помощника», а если живой камеры нет
/// (ПК без веб-камеры, браузер без `getUserMedia`) — прежний экран «Узнать по
/// фото» с выбором файла. Возвращает true, если создана заявка.
Future<bool?> openPhotoCamera(BuildContext context,
    {String? objectId,
    String? floorId,
    String? locationId,
    PhotoIdentifyOrigin origin = PhotoIdentifyOrigin.order,
    String? title}) async {
  final live = await liveCameraAvailable();
  if (!context.mounted) return null;
  return Navigator.push<bool>(
      context,
      appRoute(
          (_) => live
              ? CameraScreen(
                  objectId: objectId,
                  floorId: floorId,
                  locationId: locationId,
                  origin: origin)
              : PhotoIdentifyScreen(
                  objectId: objectId,
                  floorId: floorId,
                  locationId: locationId,
                  origin: origin),
          title: title));
}
