import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'local_backend.dart';
import 'api_error.dart';
export 'api_error.dart';

class Api {
  static bool localMode = false;
  static LocalBackend local = LocalBackend();
  static const base = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kIsWeb
        ? 'http://localhost/pklify_api'
        : 'http://10.0.2.2/pklify_api',
  );
  static String? _token;
  static http.Client? _client;
  static String? get token => _token;
  static set token(String? value) {
    // Keep connections within one login session, never across accounts.
    _client?.close();
    _client = null;
    _token = value;
  }

  static Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> data = const {},
    Uint8List? bytes,
    String? filename,
  ]) async {
    if (localMode) return local.call(action, data, token, bytes, filename);
    try {
      final uri = Uri.parse('$base/v2.php?action=$action');
      final client = _client ??= http.Client();
      final headers = <String, String>{
        if (token != null) 'Authorization': 'Bearer $token',
      };
      http.Response response;
      if (bytes != null) {
        final req = http.MultipartRequest('POST', uri)..headers.addAll(headers);
        req.fields.addAll(data.map((k, v) => MapEntry(k, '$v')));
        req.files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: filename),
        );
        response = await client
            .send(req)
            .then(http.Response.fromStream)
            .timeout(const Duration(seconds: 30));
      } else {
        response = await client
            .post(
              uri,
              headers: {...headers, 'Content-Type': 'application/json'},
              body: jsonEncode(data),
            )
            .timeout(const Duration(seconds: 30));
      }
      final body = response.body;
      final result = body.length > 65536 && !kIsWeb
          ? await compute(_decodeResponse, body)
          : _decodeResponse(body);
      if (result['success'] != true) {
        throw ApiError(result['message'] ?? 'Permintaan gagal.');
      }
      return result;
    } on ApiError {
      rethrow;
    } catch (_) {
      throw ApiError(
        'Tidak dapat terhubung. Pastikan Apache dan MySQL port 3307 aktif. Jika pengiriman terputus, periksa riwayat sebelum mengirim ulang.',
      );
    }
  }
}

Map<String, dynamic> _decodeResponse(String body) =>
    jsonDecode(body) as Map<String, dynamic>;
