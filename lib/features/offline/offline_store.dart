import 'dart:typed_data';

import 'offline_store_stub.dart' if (dart.library.io) 'offline_store_io.dart'
    as impl;

/// Хранилище на телефоне для работы без сети (шаг 27): JSON-документы
/// (заявки, очередь, якорь часов) и снимки очереди файлами. Только в
/// каталоге приложения, отдельно для каждого пользователя; при выходе из
/// аккаунта — удаляется целиком ([clear]).
///
/// ⚠️ Решение: файлы JSON, а не sqflite / drift — данных мало (свои
/// заявки исполнителя), не нужен новый нативный пакет и схема базы на
/// телефоне; запись — во временный файл и переименование (не бьётся при
/// обрыве).
abstract class OfflineStore {
  Future<Object?> read(String doc);
  Future<void> write(String doc, Object? json);
  Future<void> putPhoto(String name, Uint8List bytes);
  Future<Uint8List?> getPhoto(String name);
  Future<void> deletePhoto(String name);

  /// Сколько байт занимают снимки (для лимита ~30 МБ).
  Future<int> photoBytes();
  Future<void> clear();

  /// Каталог приложения (Android) или память (браузер в тестовом режиме).
  static OfflineStore forUser(String uid) => impl.createStore(uid);
}

/// В памяти — браузер в тестовом режиме (OFFLINE_TEST) и тесты.
class MemoryOfflineStore implements OfflineStore {
  final _docs = <String, Object?>{};
  final _photos = <String, Uint8List>{};

  @override
  Future<Object?> read(String doc) async => _docs[doc];
  @override
  Future<void> write(String doc, Object? json) async => _docs[doc] = json;
  @override
  Future<void> putPhoto(String name, Uint8List bytes) async =>
      _photos[name] = bytes;
  @override
  Future<Uint8List?> getPhoto(String name) async => _photos[name];
  @override
  Future<void> deletePhoto(String name) async => _photos.remove(name);
  @override
  Future<int> photoBytes() async =>
      _photos.values.fold<int>(0, (s, b) => s + b.length);
  @override
  Future<void> clear() async {
    _docs.clear();
    _photos.clear();
  }
}
