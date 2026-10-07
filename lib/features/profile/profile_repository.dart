import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_role.dart';

/// Сотрудник компании (строка profiles, видна коллегам по RLS).
class Member {
  const Member(
      {required this.id, required this.role, this.fullName, this.phone});
  final String id;
  final UserRole role;
  final String? fullName;
  final String? phone;

  factory Member.fromMap(Map<String, dynamic> m) => Member(
        id: m['id'] as String,
        role: UserRole.fromString(m['role'] as String?),
        fullName: (m['full_name'] as String?)?.trim(),
        phone: (m['phone'] as String?)?.trim(),
      );
}

/// Приглашение исполнителя подрядчика (таблица invites, видит только менеджер).
class Invite {
  const Invite(
      {required this.id,
      required this.token,
      required this.contractorId,
      this.expiresAt,
      this.usedAt});
  final String id;
  final String token;
  final String contractorId;
  final DateTime? expiresAt;
  final DateTime? usedAt;

  factory Invite.fromMap(Map<String, dynamic> m) => Invite(
        id: m['id'] as String,
        token: m['token'] as String,
        contractorId: m['contractor_id'] as String,
        expiresAt: DateTime.tryParse('${m['expires_at']}'),
        usedAt: DateTime.tryParse('${m['used_at']}'),
      );

  bool get active =>
      usedAt == null &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));
}

/// Компания, сотрудники, приглашения и свои настройки. Все права — в базе:
/// RLS, права на колонки profiles и RPC (create_company, accept_invite,
/// set_member_role вызываются через OnboardingRepository).
class ProfileRepository {
  final SupabaseClient _c = Supabase.instance.client;

  String? get uid => _c.auth.currentUser?.id;

  Future<String?> companyName(String companyId) async {
    final r = await _c
        .from('companies')
        .select('name')
        .eq('id', companyId)
        .maybeSingle();
    return r?['name'] as String?;
  }

  /// false — база не дала изменить название (нет прав или не применена 0011).
  Future<bool> renameCompany(String companyId, String name) async {
    final rows = await _c
        .from('companies')
        .update({'name': name.trim()})
        .eq('id', companyId)
        .select('id');
    return rows.isNotEmpty;
  }

  Future<List<Member>> members(String companyId) async {
    final rows = await _c
        .from('profiles')
        .select('id,full_name,phone,role')
        .eq('company_id', companyId)
        .order('full_name')
        .order('id');
    return [for (final r in rows) Member.fromMap(r)];
  }

  Future<List<Invite>> invites() async {
    final rows = await _c
        .from('invites')
        .select('id,token,contractor_id,expires_at,used_at,created_at')
        .order('created_at', ascending: false)
        .limit(50);
    return [for (final r in rows) Invite.fromMap(r)];
  }

  Future<void> revokeInvite(String id) =>
      _c.from('invites').delete().eq('id', id);

  /// Своё имя и телефон: только эти колонки открыты пользователю (0003).
  Future<void> updateMe({required String fullName, required String phone}) =>
      _c.from('profiles').update({
        'full_name': fullName.trim().isEmpty ? null : fullName.trim(),
        'phone': phone.trim().isEmpty ? null : phone.trim(),
      }).eq('id', uid!);

  Future<void> changePassword(String password) =>
      _c.auth.updateUser(UserAttributes(password: password));
}
