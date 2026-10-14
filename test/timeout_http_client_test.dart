import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/core/timeout_http_client.dart';
import 'package:http/http.dart' as http;

/// Сервер, который никогда не отвечает.
class _Hang extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      Completer<http.StreamedResponse>().future;
}

void main() {
  test('предел по виду запроса', () {
    final base = Uri.parse('https://x.supabase.co');
    expect(
        TimeoutHttpClient.limitFor('GET', base.resolve('/rest/v1/work_orders')),
        TimeoutHttpClient.normal);
    expect(
        TimeoutHttpClient.limitFor(
            'POST', base.resolve('/storage/v1/object/order-files/a/b.pdf')),
        TimeoutHttpClient.upload);
    expect(
        TimeoutHttpClient.limitFor(
            'GET', base.resolve('/storage/v1/object/sign/work-photos/a.jpg')),
        TimeoutHttpClient.normal);
    expect(
        TimeoutHttpClient.limitFor(
            'POST', base.resolve('/functions/v1/offline-sync')),
        TimeoutHttpClient.function);
  });

  testWidgets('зависший сервер — TimeoutException, а не вечное ожидание',
      (tester) async {
    Object? error;
    TimeoutHttpClient(_Hang())
        .get(Uri.parse('https://x.supabase.co/rest/v1/objects'))
        .catchError((Object e) {
      error = e;
      return http.Response('', 599);
    });
    await tester.pump(const Duration(seconds: 24));
    expect(error, isNull);
    await tester.pump(const Duration(seconds: 2));
    expect(error, isA<TimeoutException>());
  });
}
