import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'offline_store.dart';

OfflineStore createStore(String uid) => FileOfflineStore(uid);

/// Каталог приложения: <support>/offline/<uid>/{*.json, photos/*.jpg}.
class FileOfflineStore implements OfflineStore {
  FileOfflineStore(this.uid);
  final String uid;
  Directory? _dir;

  Future<Directory> _root() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationSupportDirectory();
    final safe = uid.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '_');
    final d = Directory('${base.path}/offline/$safe');
    await Directory('${d.path}/photos').create(recursive: true);
    return _dir = d;
  }

  String _safe(String name) => name.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');

  @override
  Future<Object?> read(String doc) async {
    try {
      final f = File('${(await _root()).path}/${_safe(doc)}.json');
      if (!await f.exists()) return null;
      return jsonDecode(await f.readAsString());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String doc, Object? json) async {
    final root = await _root();
    final f = File('${root.path}/${_safe(doc)}.json');
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(json), flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<void> putPhoto(String name, Uint8List bytes) async {
    final f = File('${(await _root()).path}/photos/${_safe(name)}');
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<Uint8List?> getPhoto(String name) async {
    final f = File('${(await _root()).path}/photos/${_safe(name)}');
    return await f.exists() ? f.readAsBytes() : null;
  }

  @override
  Future<void> deletePhoto(String name) async {
    final f = File('${(await _root()).path}/photos/${_safe(name)}');
    if (await f.exists()) await f.delete();
  }

  @override
  Future<int> photoBytes() async {
    var n = 0;
    final d = Directory('${(await _root()).path}/photos');
    await for (final e in d.list()) {
      if (e is File) n += await e.length();
    }
    return n;
  }

  @override
  Future<void> clear() async {
    final root = await _root();
    if (await root.exists()) await root.delete(recursive: true);
    _dir = null;
  }
}
