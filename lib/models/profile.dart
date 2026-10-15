import 'user_role.dart';

/// Профиль пользователя (таблица profiles).
class Profile {
  const Profile({
    required this.id,
    required this.role,
    this.companyId,
    this.fullName,
    this.phone,
    this.locale,
  });

  final String id;
  final UserRole role;
  final String? companyId;
  final String? fullName;
  final String? phone;

  /// Язык интерфейса (ru / en), выбранный пользователем. null — не выбирал.
  final String? locale;

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      role: UserRole.fromString(map['role'] as String?),
      companyId: map['company_id'] as String?,
      fullName: map['full_name'] as String?,
      phone: phoneFromRow(map),
      locale: map['locale'] as String?,
    );
  }

  /// Имя для показа; null, если не заполнено (подпись по умолчанию — из переводов).
  String? get displayName =>
      (fullName == null || fullName!.isEmpty) ? null : fullName;
}

/// Телефон из строки профиля. Шаг 28 (0025): телефоны хранятся в
/// profile_contacts (видят сам человек и менеджеры) — приходят вложенным
/// `profile_contacts(phone)`; до 0025 — полем `phone` профиля.
String? phoneFromRow(Map<String, dynamic>? m) {
  if (m == null) return null;
  final own = (m['phone'] as String?)?.trim();
  if (own != null && own.isNotEmpty) return own;
  final c = m['profile_contacts'];
  final row = c is List ? (c.isEmpty ? null : c.first) : c;
  final v = row is Map ? (row['phone'] as String?)?.trim() : null;
  return v == null || v.isEmpty ? null : v;
}
