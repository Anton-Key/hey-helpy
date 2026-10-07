import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/location.dart';
import 'photo_repository.dart';

enum CaptureProblem { cameraDenied, failed }

class CaptureException implements Exception {
  CaptureException(this.problem);
  final CaptureProblem problem;
}

/// Снимок только с камеры (без галереи), уменьшенный до ~1600 px по длинной
/// стороне, с временем съёмки и координатами (если их удалось получить).
/// null — пользователь закрыл камеру, ничего не сняв.
Future<CapturedPhoto?> capturePhoto() async {
  // Сначала разрешение на геолокацию (отдельным окном, до камеры),
  // затем координаты ищутся, пока человек снимает.
  final canLocate = await ensureLocationPermission();
  final locationFuture = canLocate ? currentPosition() : Future<Position?>.value(null);
  final XFile? file;
  try {
    file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 82,
      requestFullMetadata: false,
    );
  } on PlatformException catch (e) {
    if (e.code == 'camera_access_denied') throw CaptureException(CaptureProblem.cameraDenied);
    throw CaptureException(CaptureProblem.failed);
  }
  if (file == null) return null;
  final takenAt = DateTime.now();
  final bytes = await file.readAsBytes();
  final pos = await locationFuture;
  return CapturedPhoto(bytes: bytes, takenAt: takenAt,
      lat: pos?.latitude, lng: pos?.longitude, mockLocation: pos?.isMocked ?? false);
}
