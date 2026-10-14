import 'dart:typed_data';

import 'api.dart';

const maxUploadBytes = 5 * 1024 * 1024;

/// Stop reading at the limit, including providers that cannot report size.
Future<Uint8List> readUpload(Stream<List<int>> stream) async {
  final result = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    if (result.length + chunk.length > maxUploadBytes) {
      throw ApiError('Maksimal ukuran file 5 MB.');
    }
    result.add(chunk);
  }
  return result.takeBytes();
}
