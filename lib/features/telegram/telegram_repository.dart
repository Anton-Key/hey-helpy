import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_links.dart';
import '../../core/schema_compat.dart';
import '../../l10n/app_localizations.dart';

/// Ссылка для сотрудников без аккаунта (таблица report_links, 0018): на
/// объект (QR-код на плакате) или на всю компанию ([objectId] = null).
class ReportLink {
  const ReportLink(
      {required this.id, required this.token, this.objectId, this.createdAt});
  final String id;
  final String token;
  final String? objectId;
  final DateTime? createdAt;

  factory ReportLink.fromMap(Map<String, dynamic> m) => ReportLink(
        id: m['id'] as String,
        token: m['token'] as String,
        objectId: m['object_id'] as String?,
        createdAt: DateTime.tryParse('${m['created_at']}')?.toLocal(),
      );

  /// Ссылка на бота: открывает чат и сразу знает объект / компанию.
  String get url =>
      telegramStartLink(objectId == null ? 'co_$token' : 'obj_$token');
}

/// Привязанный к аккаунту чат Telegram (без chat_id — его приложение не видит).
class TelegramAccount {
  const TelegramAccount({this.username, this.name, this.createdAt});
  final String? username;
  final String? name;
  final DateTime? createdAt;

  /// «@maria_k» или «Мария К.».
  String? get label => (username != null && username!.isNotEmpty)
      ? '@$username'
      : ((name != null && name!.isNotEmpty) ? name : null);
}

/// Рабочая группа Telegram, подключённая к объекту.
class TelegramGroup {
  const TelegramGroup({required this.id, this.title, this.createdAt});
  final String id;
  final String? title;
  final DateTime? createdAt;
}

/// Telegram-бот со стороны приложения. Все права — в базе (0018): коды и
/// ссылки — только через RPC, привязку удаляет только её владелец, группу —
/// менеджер с правом на объект. Без 0018 — [MigrationMissing].
class TelegramRepository {
  final SupabaseClient _c = Supabase.instance.client;

  static const migration = '0018';

  String? get _uid => _c.auth.currentUser?.id;

  Future<TelegramAccount?> myAccount() => SchemaCompat.run(migration, () async {
        final uid = _uid;
        if (uid == null) return null;
        final r = await _c
            .from('telegram_links')
            .select('tg_username,tg_name,created_at')
            .eq('profile_id', uid)
            .maybeSingle();
        if (r == null) return null;
        return TelegramAccount(
          username: r['tg_username'] as String?,
          name: r['tg_name'] as String?,
          createdAt: DateTime.tryParse('${r['created_at']}')?.toLocal(),
        );
      });

  Future<void> unlinkMe() async {
    final uid = _uid;
    if (uid == null) return;
    await _c.from('telegram_links').delete().eq('profile_id', uid);
  }

  /// Одноразовый код привязки (8 знаков, 15 минут).
  Future<String> createAccountCode() => SchemaCompat.run(
      migration, () async => (await _c.rpc('tg_create_link_code')) as String);

  /// Включённая ссылка объекта ([objectId]) или компании (null).
  Future<ReportLink?> reportLink(String? objectId) =>
      SchemaCompat.run(migration, () async {
        var q = _c
            .from('report_links')
            .select('id,token,object_id,created_at')
            .eq('enabled', true);
        q = objectId == null
            ? q.isFilter('object_id', null)
            : q.eq('object_id', objectId);
        final r = await q.maybeSingle();
        return r == null ? null : ReportLink.fromMap(r);
      });

  /// Новая ссылка; прежняя (и её QR-код) перестаёт работать.
  Future<ReportLink> rotate(String? objectId) async {
    final r =
        await _c.rpc('report_link_rotate', params: {'p_object': objectId});
    return ReportLink.fromMap(Map<String, dynamic>.from(r as Map));
  }

  Future<void> disable(String? objectId) =>
      _c.rpc('report_link_disable', params: {'p_object': objectId});

  Future<List<TelegramGroup>> groups(String objectId) =>
      SchemaCompat.run(migration, () async {
        final rows = await _c
            .from('telegram_groups')
            .select('id,title,created_at')
            .eq('object_id', objectId)
            .order('created_at');
        return [
          for (final m in rows)
            TelegramGroup(
              id: m['id'] as String,
              title: m['title'] as String?,
              createdAt: DateTime.tryParse('${m['created_at']}')?.toLocal(),
            ),
        ];
      });

  /// Код подключения группы к объекту (8 знаков, 15 минут).
  Future<String> createGroupCode(String objectId) async =>
      (await _c.rpc('tg_create_group_code', params: {'p_object': objectId}))
          as String;

  Future<void> removeGroup(String id) =>
      _c.from('telegram_groups').delete().eq('id', id);
}

/// Автор заявки из Telegram (`work_orders.reporter`, 0018) словами:
/// «Мария К. (@maria) · гость» или «… · из группы: Демо БЦ».
/// null — заявка не из Telegram.
String? telegramReporterLabel(AppLocalizations l, Object? reporter) {
  if (reporter is! Map) return null;
  final name = '${reporter['name'] ?? ''}'.trim();
  final user = '${reporter['username'] ?? ''}'.trim();
  final who = [
    if (name.isNotEmpty) name,
    if (user.isNotEmpty) name.isEmpty ? '@$user' : '(@$user)',
  ].join(' ');
  // group — название группы объекта (участник группы — тоже не аккаунт).
  final group = '${reporter['group'] ?? ''}'.trim();
  return [
    who.isEmpty ? l.tgTitle : who,
    if (group.isNotEmpty)
      '${l.tgGroupChat}: $group'
    else if (reporter['guest'] == true)
      l.tgGuest,
  ].join(' · ');
}
