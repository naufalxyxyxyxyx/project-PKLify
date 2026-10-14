import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pklify/api.dart';
import 'package:pklify/uploads.dart';

void main() {
  test('stream preserves file bytes', () async {
    final result = await readUpload(
      Stream.fromIterable([
        [1, 2],
        [3, 4],
      ]),
    );
    expect(result, [1, 2, 3, 4]);
  });
  test(
    'unknown-size file stops at limit instead of reading remainder',
    () async {
      var chunks = 0;
      Stream<List<int>> file() async* {
        for (var i = 0; i < 20; i++) {
          chunks++;
          yield Uint8List(1024 * 1024);
        }
      }

      await expectLater(readUpload(file()), throwsA(isA<ApiError>()));
      expect(chunks, 6);
    },
  );
  test('exactly 5 MB remains accepted', () async {
    final result = await readUpload(Stream.value(Uint8List(maxUploadBytes)));
    expect(result.length, maxUploadBytes);
  });
}
