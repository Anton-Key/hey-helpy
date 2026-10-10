import 'work_order.dart';

/// Период фильтра: пресеты и «Свой период».
enum PeriodPreset { today, days7, days30, thisMonth, lastMonth, custom }

/// По какой дате считать период: создания или сроку.
enum DateField { created, due }

/// Сортировка списка заявок.
enum OrderSort { newest, oldest, due, priority, status, object }

/// Быстрые пресеты над фильтром: сегменты «Все / Открытые / Просрочено».
enum OrderSegment { all, open, overdue }

/// Тип заявки: разовая или повторяющаяся (work_orders.recurrence).
enum RecurrenceFilter { once, recurring }

/// Один выбранный фильтр — одна таблетка в строке применённых фильтров и
/// одна единица в счётчике «Фильтры · N» ([OrderFilter.activeKeys]).
enum FilterKey {
  period,
  status,
  object,
  room,
  contractor,
  layer,
  priority,
  recurrence,
  channel,
  photo,
  returned,
  mine,
  toMe,
}

/// Главные фильтры: на широком экране — таблетками рядом с поиском.
const kMainFilterKeys = [
  FilterKey.period,
  FilterKey.status,
  FilterKey.object,
  FilterKey.contractor,
];

/// Пункт «Без подрядчика» в фильтре подрядчиков.
const kNoContractor = 'none';

/// Пункт «Просрочено» в фильтре статусов (это не статус в базе).
const kOverdue = 'overdue';

/// Порядок пунктов фильтра статусов и сортировки «По статусу».
const kStatusOrder = [
  kOverdue,
  'new',
  'assigned',
  'in_progress',
  'returned',
  'on_review',
  'done',
  'cancelled',
];

/// Срочность от самой высокой.
const kPriorityOrder = ['critical', 'high', 'normal', 'low'];

/// Источник заявки (work_orders.input_channel).
const kChannels = ['voice', 'text', 'button'];

/// Одно условие запроса PostgREST: `column=op.value`; для [column] = `or` —
/// `or=(value)`. Строки, а не вызовы клиента, — чтобы проверять тестами.
class ServerCond {
  const ServerCond(this.column, this.op, this.value);
  const ServerCond.or(this.value)
      : column = 'or',
        op = '';
  final String column;
  final String op;
  final String value;

  @override
  String toString() => column == 'or' ? 'or=($value)' : '$column=$op.$value';

  @override
  bool operator ==(Object other) =>
      other is ServerCond && other.toString() == toString();

  @override
  int get hashCode => toString().hashCode;
}

/// Фильтр и сортировка списка заявок. Неизменяемый: любое изменение —
/// новый объект через [copyWith].
///
/// Фильтр работает поверх того, что пользователь и так видит (RLS): он только
/// сужает выборку. На сервер уходят условия [serverConditions], та же логика
/// в памяти — [matches] (для проверки и для «Просрочено» относительно «сейчас»).
class OrderFilter {
  const OrderFilter({
    this.period,
    this.dateField = DateField.created,
    this.customFrom,
    this.customTo,
    this.objectIds = const {},
    this.locationIds = const {},
    this.contractorIds = const {},
    this.priorities = const {},
    this.statuses = const {},
    this.layerIds = const {},
    this.channels = const {},
    this.recurrence,
    this.needsPhoto = false,
    this.returned = false,
    this.createdByMe = false,
    this.assignedToMe = false,
    this.sort = OrderSort.newest,
    this.segment = OrderSegment.all,
  });

  final PeriodPreset? period;
  final DateField dateField;

  /// «Свой период»: первый и последний день (включительно).
  final DateTime? customFrom;
  final DateTime? customTo;

  final Set<String> objectIds;

  /// Помещения — только если выбран ровно один объект ([effectiveLocationIds]).
  final Set<String> locationIds;

  /// id подрядчиков и, возможно, [kNoContractor].
  final Set<String> contractorIds;
  final Set<String> priorities;

  /// Статусы и, возможно, [kOverdue].
  final Set<String> statuses;
  final Set<String> layerIds;
  final Set<String> channels;
  final RecurrenceFilter? recurrence;
  final bool needsPhoto;
  final bool returned;
  final bool createdByMe;

  /// «Назначено мне» (исполнитель): назначена мне лично или моему подрядчику
  /// без конкретного исполнителя — то есть не коллеге.
  final bool assignedToMe;

  final OrderSort sort;
  final OrderSegment segment;

  static const empty = OrderFilter();

  OrderFilter copyWith({
    PeriodPreset? period,
    bool clearPeriod = false,
    DateField? dateField,
    DateTime? customFrom,
    DateTime? customTo,
    Set<String>? objectIds,
    Set<String>? locationIds,
    Set<String>? contractorIds,
    Set<String>? priorities,
    Set<String>? statuses,
    Set<String>? layerIds,
    Set<String>? channels,
    RecurrenceFilter? recurrence,
    bool clearRecurrence = false,
    bool? needsPhoto,
    bool? returned,
    bool? createdByMe,
    bool? assignedToMe,
    OrderSort? sort,
    OrderSegment? segment,
  }) {
    final objs = objectIds ?? this.objectIds;
    return OrderFilter(
      period: clearPeriod ? null : (period ?? this.period),
      dateField: dateField ?? this.dateField,
      customFrom: clearPeriod ? null : (customFrom ?? this.customFrom),
      customTo: clearPeriod ? null : (customTo ?? this.customTo),
      objectIds: objs,
      // Помещения имеют смысл только внутри одного объекта.
      locationIds: objs.length == 1 ? (locationIds ?? this.locationIds) : {},
      contractorIds: contractorIds ?? this.contractorIds,
      priorities: priorities ?? this.priorities,
      statuses: statuses ?? this.statuses,
      layerIds: layerIds ?? this.layerIds,
      channels: channels ?? this.channels,
      recurrence: clearRecurrence ? null : (recurrence ?? this.recurrence),
      needsPhoto: needsPhoto ?? this.needsPhoto,
      returned: returned ?? this.returned,
      createdByMe: createdByMe ?? this.createdByMe,
      assignedToMe: assignedToMe ?? this.assignedToMe,
      sort: sort ?? this.sort,
      segment: segment ?? this.segment,
    );
  }

  /// Помещения, которые реально фильтруют (выбран один объект).
  Set<String> get effectiveLocationIds =>
      objectIds.length == 1 ? locationIds : const {};

  /// Сколько пунктов выбрано в «Ещё».
  int get moreCount =>
      (recurrence != null ? 1 : 0) +
      channels.length +
      (needsPhoto ? 1 : 0) +
      (returned ? 1 : 0) +
      (createdByMe ? 1 : 0) +
      (assignedToMe ? 1 : 0);

  bool get hasPeriod =>
      period != null &&
      (period != PeriodPreset.custom ||
          (customFrom != null && customTo != null));

  /// Выбран хоть один фильтр (сортировка и сегмент не считаются).
  bool get hasFilters =>
      hasPeriod ||
      objectIds.isNotEmpty ||
      contractorIds.isNotEmpty ||
      priorities.isNotEmpty ||
      statuses.isNotEmpty ||
      layerIds.isNotEmpty ||
      moreCount > 0;

  /// Выбранные фильтры по порядку (порядок таблеток и окна «Фильтры»).
  List<FilterKey> get activeKeys => [
        if (hasPeriod) FilterKey.period,
        if (statuses.isNotEmpty) FilterKey.status,
        if (objectIds.isNotEmpty) FilterKey.object,
        if (effectiveLocationIds.isNotEmpty) FilterKey.room,
        if (contractorIds.isNotEmpty) FilterKey.contractor,
        if (layerIds.isNotEmpty) FilterKey.layer,
        if (priorities.isNotEmpty) FilterKey.priority,
        if (recurrence != null) FilterKey.recurrence,
        if (channels.isNotEmpty) FilterKey.channel,
        if (needsPhoto) FilterKey.photo,
        if (returned) FilterKey.returned,
        if (createdByMe) FilterKey.mine,
        if (assignedToMe) FilterKey.toMe,
      ];

  /// Число на кнопке «Фильтры · N».
  int get activeCount => activeKeys.length;

  /// Снять один фильтр (крестик на таблетке).
  OrderFilter without(FilterKey k) => switch (k) {
        FilterKey.period =>
          copyWith(clearPeriod: true, dateField: DateField.created),
        FilterKey.status => copyWith(statuses: const {}),
        FilterKey.object => copyWith(objectIds: const {}),
        FilterKey.room => copyWith(locationIds: const {}),
        FilterKey.contractor => copyWith(contractorIds: const {}),
        FilterKey.layer => copyWith(layerIds: const {}),
        FilterKey.priority => copyWith(priorities: const {}),
        FilterKey.recurrence => copyWith(clearRecurrence: true),
        FilterKey.channel => copyWith(channels: const {}),
        FilterKey.photo => copyWith(needsPhoto: false),
        FilterKey.returned => copyWith(returned: false),
        FilterKey.mine => copyWith(createdByMe: false),
        FilterKey.toMe => copyWith(assignedToMe: false),
      };

  /// «Сбросить всё»: фильтры и сегмент — к начальным, сортировка остаётся.
  OrderFilter cleared() => OrderFilter(sort: sort);

  /// Границы периода: [from] включительно, [to] — не включительно (начало
  /// следующего дня). null — период не выбран.
  ({DateTime from, DateTime to})? range(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    DateTime day(int shift) =>
        DateTime(today.year, today.month, today.day + shift);
    switch (period) {
      case null:
        return null;
      case PeriodPreset.today:
        return (from: today, to: day(1));
      case PeriodPreset.days7:
        return (from: day(-6), to: day(1));
      case PeriodPreset.days30:
        return (from: day(-29), to: day(1));
      case PeriodPreset.thisMonth:
        return (
          from: DateTime(now.year, now.month),
          to: DateTime(now.year, now.month + 1)
        );
      case PeriodPreset.lastMonth:
        return (
          from: DateTime(now.year, now.month - 1),
          to: DateTime(now.year, now.month)
        );
      case PeriodPreset.custom:
        final a = customFrom, b = customTo;
        if (a == null || b == null) return null;
        final first = a.isAfter(b) ? b : a;
        final last = a.isAfter(b) ? a : b;
        return (
          from: DateTime(first.year, first.month, first.day),
          to: DateTime(last.year, last.month, last.day + 1)
        );
    }
  }

  // -------------------------------------------------------------------
  // Сервер
  // -------------------------------------------------------------------

  /// Условия для запроса к work_orders (поверх RLS). Сегмент и поиск сюда
  /// не входят — они считаются в памяти, чтобы показать счётчики сегментов.
  List<ServerCond> serverConditions(
      {required DateTime now,
      String? uid,
      List<String> myExecutorIds = const []}) {
    final out = <ServerCond>[];
    final orGroups = <String>[];
    String list(Iterable<String> v) => '(${v.join(',')})';
    String ts(DateTime d) => d.toUtc().toIso8601String();

    final r = range(now);
    if (r != null) {
      final col = dateField == DateField.due ? 'due_at' : 'created_at';
      out
        ..add(ServerCond(col, 'gte', ts(r.from)))
        ..add(ServerCond(col, 'lt', ts(r.to)));
    }
    if (objectIds.isNotEmpty) {
      out.add(ServerCond('object_id', 'in', list(_sorted(objectIds))));
    }
    final locs = effectiveLocationIds;
    if (locs.isNotEmpty) {
      out.add(ServerCond('location_id', 'in', list(_sorted(locs))));
    }
    if (contractorIds.isNotEmpty) {
      final ids = _sorted(contractorIds.where((c) => c != kNoContractor));
      final none = contractorIds.contains(kNoContractor);
      if (ids.isEmpty) {
        out.add(const ServerCond('assigned_contractor_id', 'is', 'null'));
      } else if (!none) {
        out.add(ServerCond('assigned_contractor_id', 'in', list(ids)));
      } else {
        orGroups.add('assigned_contractor_id.in.${list(ids)},'
            'assigned_contractor_id.is.null');
      }
    }
    if (priorities.isNotEmpty) {
      out.add(ServerCond(
          'priority', 'in', list(_ordered(priorities, kPriorityOrder))));
    }
    if (statuses.isNotEmpty) {
      final real = _ordered(statuses.where((s) => s != kOverdue), kStatusOrder);
      final overdue = statuses.contains(kOverdue);
      const closed = '(done,cancelled)';
      if (!overdue) {
        out.add(ServerCond('status', 'in', list(real)));
      } else if (real.isEmpty) {
        out
          ..add(const ServerCond('status', 'not.in', closed))
          ..add(ServerCond('due_at', 'lt', ts(now)));
      } else {
        orGroups.add('status.in.${list(real)},'
            'and(status.not.in.$closed,due_at.lt."${ts(now)}")');
      }
    }
    if (layerIds.isNotEmpty) {
      out.add(ServerCond('layer_id', 'in', list(_sorted(layerIds))));
    }
    switch (recurrence) {
      case RecurrenceFilter.once:
        out.add(const ServerCond('recurrence', 'is', 'null'));
      case RecurrenceFilter.recurring:
        out.add(const ServerCond('recurrence', 'not.is', 'null'));
      case null:
        break;
    }
    if (channels.isNotEmpty) {
      out.add(ServerCond(
          'input_channel', 'in', list(_ordered(channels, kChannels))));
    }
    if (needsPhoto) out.add(const ServerCond('requires_photo', 'is', 'true'));
    if (returned) out.add(const ServerCond('return_count', 'gt', '0'));
    if (createdByMe && uid != null) {
      out.add(ServerCond('created_by', 'eq', uid));
    }
    if (assignedToMe) {
      final ids = _sorted(myExecutorIds);
      orGroups.add(ids.isEmpty
          ? 'assigned_executor_id.is.null'
          : 'assigned_executor_id.in.${list(ids)},assigned_executor_id.is.null');
    }

    // Несколько групп «или» — одним параметром: or=(and(or(…),or(…))).
    if (orGroups.length == 1) {
      out.add(ServerCond.or(orGroups.single));
    } else if (orGroups.length > 1) {
      out.add(ServerCond.or('and(${orGroups.map((g) => 'or($g)').join(',')})'));
    }
    return out;
  }

  /// Условия сегмента «Открытые» / «Просрочено» — для запроса только
  /// количества («Показать N заявок»); список считает сегмент в памяти.
  List<ServerCond> segmentConditions(DateTime now) => switch (segment) {
        OrderSegment.all => const [],
        OrderSegment.open => const [
            ServerCond('status', 'not.in', '(done,cancelled)')
          ],
        OrderSegment.overdue => [
            const ServerCond('status', 'not.in', '(done,cancelled)'),
            ServerCond('due_at', 'lt', now.toUtc().toIso8601String()),
          ],
      };

  // -------------------------------------------------------------------
  // Память
  // -------------------------------------------------------------------

  /// То же, что [serverConditions], для одной заявки.
  bool matches(WorkOrder w,
      {required DateTime now,
      String? uid,
      List<String> myExecutorIds = const []}) {
    final r = range(now);
    if (r != null) {
      final d = dateField == DateField.due ? w.dueAt : w.createdAt;
      if (d == null || d.isBefore(r.from) || !d.isBefore(r.to)) return false;
    }
    if (objectIds.isNotEmpty && !objectIds.contains(w.objectId)) return false;
    final locs = effectiveLocationIds;
    if (locs.isNotEmpty && !locs.contains(w.locationId)) return false;
    if (contractorIds.isNotEmpty) {
      final key = w.contractorId ?? kNoContractor;
      if (!contractorIds.contains(key)) return false;
    }
    if (priorities.isNotEmpty && !priorities.contains(w.priority)) return false;
    if (statuses.isNotEmpty) {
      final ok = statuses.contains(w.status) ||
          (statuses.contains(kOverdue) && w.isOverdue(now));
      if (!ok) return false;
    }
    if (layerIds.isNotEmpty && !layerIds.contains(w.layerId)) return false;
    if (recurrence == RecurrenceFilter.once && w.recurring) return false;
    if (recurrence == RecurrenceFilter.recurring && !w.recurring) return false;
    if (channels.isNotEmpty && !channels.contains(w.inputChannel)) return false;
    if (needsPhoto && !w.requiresPhoto) return false;
    if (returned && w.returnCount <= 0) return false;
    if (createdByMe && uid != null && w.createdBy != uid) return false;
    if (assignedToMe &&
        w.executorId != null &&
        !myExecutorIds.contains(w.executorId)) {
      return false;
    }
    return true;
  }

  /// Подходит ли заявка под сегмент.
  bool matchesSegment(WorkOrder w, DateTime now) => switch (segment) {
        OrderSegment.all => true,
        OrderSegment.open => w.isOpen,
        OrderSegment.overdue => w.isOverdue(now),
      };

  // -------------------------------------------------------------------
  // Сохранение: настройки на устройстве и адрес страницы
  // -------------------------------------------------------------------

  /// Короткие параметры адреса. Значения по умолчанию не пишутся.
  Map<String, String> toQuery() {
    final q = <String, String>{};
    String join(Iterable<String> v) => _sorted(v).join(',');
    if (period != null) q['period'] = _periodKeys[period]!;
    if (period == PeriodPreset.custom) {
      if (customFrom != null) q['from'] = _date(customFrom!);
      if (customTo != null) q['to'] = _date(customTo!);
    }
    if (dateField == DateField.due) q['by'] = 'due';
    if (objectIds.isNotEmpty) q['obj'] = join(objectIds);
    if (effectiveLocationIds.isNotEmpty) q['loc'] = join(effectiveLocationIds);
    if (contractorIds.isNotEmpty) q['con'] = join(contractorIds);
    if (priorities.isNotEmpty) q['pri'] = join(priorities);
    if (statuses.isNotEmpty) q['st'] = join(statuses);
    if (layerIds.isNotEmpty) q['layer'] = join(layerIds);
    if (recurrence != null) q['rec'] = recurrence!.name;
    if (channels.isNotEmpty) q['src'] = join(channels);
    if (needsPhoto) q['photo'] = '1';
    if (returned) q['ret'] = '1';
    if (createdByMe) q['mine'] = '1';
    if (assignedToMe) q['tome'] = '1';
    if (sort != OrderSort.newest) q['sort'] = sort.name;
    if (segment != OrderSegment.all) q['seg'] = segment.name;
    return q;
  }

  /// Ключи, которые понимает [fromQuery] (остальные параметры адреса — чужие).
  static const queryKeys = {
    'period',
    'from',
    'to',
    'by',
    'obj',
    'loc',
    'con',
    'pri',
    'st',
    'layer',
    'rec',
    'src',
    'photo',
    'ret',
    'mine',
    'tome',
    'sort',
    'seg',
  };

  /// Разбор параметров. Неизвестные значения пропускаются, а не ломают список.
  static OrderFilter fromQuery(Map<String, String> q) {
    Set<String> set(String key, [Iterable<String>? allowed]) {
      final v = q[key];
      if (v == null || v.isEmpty) return const {};
      return {
        for (final s in v.split(','))
          if (s.trim().isNotEmpty &&
              (allowed == null || allowed.contains(s.trim())))
            s.trim()
      };
    }

    T? byName<T extends Enum>(List<T> values, String? name) {
      for (final v in values) {
        if (v.name == name) return v;
      }
      return null;
    }

    PeriodPreset? period;
    _periodKeys.forEach((k, v) {
      if (v == q['period']) period = k;
    });
    final objs = set('obj');
    return OrderFilter(
      period: period,
      dateField: q['by'] == 'due' ? DateField.due : DateField.created,
      customFrom: _parseDate(q['from']),
      customTo: _parseDate(q['to']),
      objectIds: objs,
      locationIds: objs.length == 1 ? set('loc') : const {},
      contractorIds: set('con'),
      priorities: set('pri', kPriorityOrder),
      statuses: set('st', kStatusOrder),
      layerIds: set('layer'),
      channels: set('src', kChannels),
      recurrence: byName(RecurrenceFilter.values, q['rec']),
      needsPhoto: q['photo'] == '1',
      returned: q['ret'] == '1',
      createdByMe: q['mine'] == '1',
      assignedToMe: q['tome'] == '1',
      sort: byName(OrderSort.values, q['sort']) ?? OrderSort.newest,
      segment: byName(OrderSegment.values, q['seg']) ?? OrderSegment.all,
    );
  }

  /// Строка для shared_preferences.
  String serialize() => Uri(queryParameters: toQuery()).query;

  static OrderFilter deserialize(String? s) {
    if (s == null || s.isEmpty) return empty;
    try {
      return fromQuery(Uri.splitQueryString(s));
    } catch (_) {
      return empty;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is OrderFilter && other.serialize() == serialize();

  @override
  int get hashCode => serialize().hashCode;

  @override
  String toString() => 'OrderFilter(${serialize()})';

  static const _periodKeys = {
    PeriodPreset.today: 'today',
    PeriodPreset.days7: '7d',
    PeriodPreset.days30: '30d',
    PeriodPreset.thisMonth: 'month',
    PeriodPreset.lastMonth: 'prev',
    PeriodPreset.custom: 'custom',
  };

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDate(String? s) {
    if (s == null) return null;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
    if (m == null) return null;
    return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }
}

List<String> _sorted(Iterable<String> v) => v.toList()..sort();

/// Значения в порядке [order] (известные), затем остальные по алфавиту.
List<String> _ordered(Iterable<String> v, List<String> order) {
  final known = [
    for (final o in order)
      if (v.contains(o)) o
  ];
  final rest = _sorted(v.where((x) => !order.contains(x)));
  return [...known, ...rest];
}

// ---------------------------------------------------------------------
// Сортировка и группы
// ---------------------------------------------------------------------

int _statusRank(WorkOrder w, DateTime now) {
  if (w.isOverdue(now)) return 0;
  final i = kStatusOrder.indexOf(w.status);
  return i < 0 ? kStatusOrder.length : i;
}

int _priorityRank(String p) {
  final i = kPriorityOrder.indexOf(p);
  return i < 0 ? kPriorityOrder.indexOf('normal') : i;
}

int _newestFirst(WorkOrder a, WorkOrder b) {
  final x = a.createdAt, y = b.createdAt;
  if (x == null && y == null) return a.id.compareTo(b.id);
  if (x == null) return 1;
  if (y == null) return -1;
  final c = y.compareTo(x);
  return c != 0 ? c : a.id.compareTo(b.id);
}

/// Сортирует заявки. [objectName] — название объекта по id (для «По объекту»).
List<WorkOrder> sortOrders(Iterable<WorkOrder> items, OrderSort sort,
    {required DateTime now, String Function(String? objectId)? objectName}) {
  final list = items.toList();
  int cmp(WorkOrder a, WorkOrder b) {
    switch (sort) {
      case OrderSort.newest:
        return _newestFirst(a, b);
      case OrderSort.oldest:
        return _newestFirst(b, a);
      case OrderSort.due:
        // Ближайший срок сверху, без срока — в конце.
        final x = a.dueAt, y = b.dueAt;
        if (x == null && y == null) return _newestFirst(a, b);
        if (x == null) return 1;
        if (y == null) return -1;
        final c = x.compareTo(y);
        return c != 0 ? c : _newestFirst(a, b);
      case OrderSort.priority:
        final c =
            _priorityRank(a.priority).compareTo(_priorityRank(b.priority));
        return c != 0 ? c : _newestFirst(a, b);
      case OrderSort.status:
        final c = _statusRank(a, now).compareTo(_statusRank(b, now));
        return c != 0 ? c : _newestFirst(a, b);
      case OrderSort.object:
        final na = objectName?.call(a.objectId),
            nb = objectName?.call(b.objectId);
        // Без объекта — в конце.
        if (a.objectId == null && b.objectId != null) return 1;
        if (b.objectId == null && a.objectId != null) return -1;
        final c = (na ?? '').toLowerCase().compareTo((nb ?? '').toLowerCase());
        return c != 0 ? c : _newestFirst(a, b);
    }
  }

  list.sort(cmp);
  return list;
}

/// Группа списка: [key] — «today» / «earlier», код срочности, статуса
/// (или [kOverdue]), id объекта (`''` — без объекта); при сортировке
/// «По сроку» — одна группа с ключом `''`.
class OrderGroup {
  const OrderGroup(this.key, this.items);
  final String key;
  final List<WorkOrder> items;
}

/// Делит уже отсортированный список на группы по смыслу сортировки.
List<OrderGroup> groupOrders(List<WorkOrder> sorted, OrderSort sort,
    {required DateTime now}) {
  final today = DateTime(now.year, now.month, now.day);
  String key(WorkOrder w) => switch (sort) {
        OrderSort.newest ||
        OrderSort.oldest =>
          (w.createdAt != null && !w.createdAt!.isBefore(today))
              ? 'today'
              : 'earlier',
        OrderSort.priority =>
          kPriorityOrder.contains(w.priority) ? w.priority : 'normal',
        OrderSort.status => w.isOverdue(now) ? kOverdue : w.status,
        OrderSort.object => w.objectId ?? '',
        OrderSort.due => '',
      };
  final out = <OrderGroup>[];
  for (final w in sorted) {
    final k = key(w);
    if (out.isNotEmpty && out.last.key == k) {
      out.last.items.add(w);
    } else {
      out.add(OrderGroup(k, [w]));
    }
  }
  return out;
}

/// Итог для экрана: заявки после сегмента и поиска (отсортированы) и
/// счётчики сегментов с учётом остальных фильтров и поиска.
class OrderListView {
  const OrderListView(
      {required this.items,
      required this.all,
      required this.open,
      required this.overdue});
  final List<WorkOrder> items;
  final int all;
  final int open;
  final int overdue;
}

/// Применяет фильтр (ещё раз, в памяти), поиск, сегмент и сортировку к
/// заявкам, которые пришли с сервера. [search] — подходит ли заявка под
/// строку поиска (названия объектов и слоёв знает экран).
OrderListView buildOrderList(List<WorkOrder> loaded, OrderFilter f,
    {required DateTime now,
    String? uid,
    List<String> myExecutorIds = const [],
    bool Function(WorkOrder)? search,
    String Function(String? objectId)? objectName}) {
  final base = [
    for (final w in loaded)
      if (f.matches(w, now: now, uid: uid, myExecutorIds: myExecutorIds) &&
          (search == null || search(w)))
        w
  ];
  return OrderListView(
    items: sortOrders(base.where((w) => f.matchesSegment(w, now)), f.sort,
        now: now, objectName: objectName),
    all: base.length,
    open: base.where((w) => w.isOpen).length,
    overdue: base.where((w) => w.isOverdue(now)).length,
  );
}
