import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pklify/api.dart';

void main() {
  tearDown(() => Api.token = null);
  test('wrong password is a failure, not a demo login', () async {
    await http.runWithClient(
      () async {
        await expectLater(
          Api.call('login', {'identity': 'unknown', 'password': 'wrong'}),
          throwsA(
            isA<ApiError>().having(
              (e) => e.message,
              'message',
              'NIS/NIP atau kata sandi salah.',
            ),
          ),
        );
      },
      () => MockClient(
        (request) async => http.Response(
          jsonEncode({
            'success': false,
            'message': 'NIS/NIP atau kata sandi salah.',
          }),
          401,
        ),
      ),
    );
  });
  test('authenticated requests carry session token', () async {
    Api.token = 'test-token';
    await http.runWithClient(
      () async {
        final result = await Api.call('overview');
        expect(result['students'], isEmpty);
      },
      () => MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response('{"success":true,"students":[]}', 200);
      }),
    );
  });
  test('network failure cannot be reported as saved', () async {
    await http.runWithClient(() async {
      await expectLater(
        Api.call('activity', {'kind': 'jurnal'}),
        throwsA(isA<ApiError>()),
      );
    }, () => MockClient((_) async => throw http.ClientException('offline')));
  });
  test(
    'server HTML error is converted into readable connection error',
    () async {
      await http.runWithClient(
        () async {
          await expectLater(Api.call('overview'), throwsA(isA<ApiError>()));
        },
        () => MockClient(
          (_) async => http.Response('<h1>Server unavailable</h1>', 500),
        ),
      );
    },
  );
}
