import 'package:shared_preferences/shared_preferences.dart';

import '../../core/web_url.dart';
import 'order_filter.dart';

/// Где хранится фильтр списка заявок: на устройстве — отдельно для каждого
/// пользователя, в вебе — ещё и в адресе страницы.
class OrderFilterStore {
  const OrderFilterStore();

  static String _key(String uid) => 'orders_filter.$uid';

  /// Фильтр при открытии: из ссылки (если в адресе есть параметры фильтра),
  /// иначе сохранённый на устройстве, иначе пустой.
  Future<OrderFilter> load(String? uid) async {
    final fromUrl = AppUrl.takeInitial(OrderFilter.queryKeys);
    if (fromUrl.isNotEmpty) return OrderFilter.fromQuery(fromUrl);
    if (uid == null) return OrderFilter.empty;
    try {
      final p = await SharedPreferences.getInstance();
      return OrderFilter.deserialize(p.getString(_key(uid)));
    } catch (_) {
      return OrderFilter.empty;
    }
  }

  Future<void> save(String? uid, OrderFilter f) async {
    AppUrl.replaceQuery(f.toQuery());
    if (uid == null) return;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key(uid), f.serialize());
    } catch (_) {}
  }

  /// Убрать фильтр из адреса (ушли со списка заявок).
  void clearUrl() => AppUrl.replaceQuery(const {});
}
