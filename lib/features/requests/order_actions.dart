/// Что можно этому пользователю с этой заявкой (шаг 26).
///
/// Одна чистая функция для всей карточки заявки. Те же правила проверяет
/// база (миграция 0023: `trg_wo_status_flow`, `trg_wo_guard`, политики
/// фото, чек-листа и визитов) — интерфейс лишь не показывает кнопки,
/// которые всё равно не сработают.
///
/// | Действие | Кто |
/// |---|---|
/// | назначить подрядчика | менеджер / админ |
/// | правка текста | менеджер / админ; автор — пока работа не начата |
/// | начать, фото «после», на проверку | только исполнитель назначенного подрядчика |
/// | принять / вернуть | менеджер / админ, но не тот, кто отправил на проверку |
/// | отменить | менеджер / админ; автор — пока работа не начата |
library;

/// Пользователь: роль, id и подрядчики, где он исполнитель (`executors`).
/// Менеджер «собственной службы» — исполнитель её подрядчика (см. CLAUDE.md).
class OrderActor {
  const OrderActor(
      {required this.role, required this.uid, this.contractorIds = const {}});
  final String? role;
  final String? uid;
  final Set<String> contractorIds;

  bool get isManager => role == 'admin' || role == 'manager';
}

class OrderActions {
  const OrderActions({
    this.assign = false,
    this.edit = false,
    this.start = false,
    this.addAfterPhoto = false,
    this.submit = false,
    this.accept = false,
    this.cancel = false,
    this.addBeforePhoto = false,
    this.assignFirstHint = false,
    this.otherManagerMustAccept = false,
    this.watchProgress = false,
    this.isExecutor = false,
  });

  final bool assign;
  final bool edit;
  final bool start;
  final bool addAfterPhoto;
  final bool submit;

  /// Принять и вернуть — одно право.
  final bool accept;
  final bool cancel;
  final bool addBeforePhoto;

  /// Менеджер, заявка без подрядчика: «Сначала назначьте подрядчика».
  final bool assignFirstHint;

  /// Менеджер сам отправил на проверку (старые данные или своя служба):
  /// «Принять должен другой менеджер».
  final bool otherManagerMustAccept;

  /// Менеджер видит заявку в работе: строка-статус вместо кнопок исполнителя.
  final bool watchProgress;

  /// Пользователь — исполнитель назначенного подрядчика.
  final bool isExecutor;
}

const _beforeWork = {'new', 'assigned'};
const _startable = {'new', 'assigned', 'returned'};

OrderActions orderActions(
  OrderActor who, {
  required String status,
  String? createdBy,
  String? contractorId,
  String? submittedBy,
}) {
  final mgr = who.isManager;
  final author = who.uid != null && createdBy == who.uid;
  final exec = contractorId != null && who.contractorIds.contains(contractorId);
  final open = status != 'done' && status != 'cancelled';
  final selfSubmitted = submittedBy != null && submittedBy == who.uid;
  return OrderActions(
    assign: mgr && _startable.contains(status),
    edit: open && (mgr || (author && _beforeWork.contains(status))),
    start: exec && _startable.contains(status),
    addAfterPhoto: exec && status == 'in_progress',
    submit: exec && status == 'in_progress',
    accept: mgr && status == 'on_review' && !selfSubmitted,
    cancel: open && (mgr || (author && _beforeWork.contains(status))),
    addBeforePhoto: (mgr || author) && _beforeWork.contains(status),
    assignFirstHint: mgr && contractorId == null && _startable.contains(status),
    otherManagerMustAccept: mgr && status == 'on_review' && selfSubmitted,
    watchProgress: mgr && !exec && status == 'in_progress',
    isExecutor: exec,
  );
}
