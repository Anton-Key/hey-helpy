/// Роли пользователя в Hey Helpy (соответствуют profiles.role в БД).
enum UserRole {
  admin,
  manager,
  requester,
  contractor,
  executor;

  static UserRole fromString(String? value) {
    return UserRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => UserRole.requester,
    );
  }

  String get title {
    switch (this) {
      case UserRole.admin:
        return 'Администратор';
      case UserRole.manager:
        return 'Менеджер';
      case UserRole.requester:
        return 'Заявитель';
      case UserRole.contractor:
        return 'Подрядчик';
      case UserRole.executor:
        return 'Исполнитель';
    }
  }

  bool get canManage => this == UserRole.admin || this == UserRole.manager;
  bool get canSeeReports => this == UserRole.admin || this == UserRole.manager;
  bool get canAdmin => this == UserRole.admin;
}
