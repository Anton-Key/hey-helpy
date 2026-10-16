import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/offline/offline_logic.dart';

/// Шаг 28: фото «до» и планы этажей на телефоне — что держать, что удалить.
void main() {
  test('mediaCleanup: ненужное удаляется, считается только свой вид', () {
    final stored = {
      offlinePhotoName('a'): 100,
      offlinePhotoName('b'): 200,
      offlinePlanName('f1', 'c/o/f1/plan.png'): 5000,
      'off_q1.jpg': 999, // снимок очереди — не трогаем
    };
    final r = mediaCleanup([offlinePhotoName('a')], stored, isOfflinePhotoName);
    expect(r.drop, [offlinePhotoName('b')]);
    expect(r.used, 100);
    final p = mediaCleanup(<String>[], stored, isOfflinePlanName);
    expect(p.drop, [offlinePlanName('f1', 'c/o/f1/plan.png')]);
    expect(p.used, 0);
  });

  test('mediaFits: бюджет и предел одного файла', () {
    expect(mediaFits(0, 1000, kOfflinePhotoBudget, kOfflinePhotoMax), isTrue);
    expect(
        mediaFits(kOfflinePhotoBudget - 10, 100, kOfflinePhotoBudget,
            kOfflinePhotoMax),
        isFalse);
    expect(
        mediaFits(0, kOfflinePlanMax + 1, kOfflinePlanBudget, kOfflinePlanMax),
        isFalse);
    expect(mediaFits(0, 0, kOfflinePhotoBudget, kOfflinePhotoMax), isFalse);
  });

  test('beforePhotosToKeep: только «до», без демо, по порядку заявок', () {
    final rows = [
      {
        'work_order_id': 'o2',
        'stage': 'before',
        'storage_path': 'c/o2/1.jpg',
        'created_at': '2'
      },
      {'work_order_id': 'o1', 'stage': 'after', 'storage_path': 'c/o1/a.jpg'},
      {
        'work_order_id': 'o1',
        'stage': 'before',
        'storage_path': 'demo/ac_indoor.jpg'
      },
      {
        'work_order_id': 'o1',
        'stage': 'before',
        'storage_path': 'c/o1/2.jpg',
        'created_at': '3'
      },
      {
        'work_order_id': 'o2',
        'stage': 'before',
        'storage_path': 'c/o2/0.jpg',
        'created_at': '1'
      },
      {'work_order_id': 'o9', 'stage': 'before', 'storage_path': 'c/o9/x.jpg'},
    ];
    final keep = beforePhotosToKeep(['o1', 'o2'], rows);
    expect([for (final r in keep) r['storage_path']],
        ['c/o1/2.jpg', 'c/o2/0.jpg', 'c/o2/1.jpg']);
  });

  test('имя плана зависит от файла на сервере', () {
    expect(offlinePlanName('f1', 'c/o/f1/plan v2.png'), 'plan_f1_plan_v2.png');
    expect(offlinePlanName('f1', 'a.png') == offlinePlanName('f1', 'b.png'),
        isFalse);
  });
}
