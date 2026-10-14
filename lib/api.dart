import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class Api {
  static const base = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kIsWeb
        ? 'http://localhost/pklify_api'
        : 'http://10.0.2.2/pklify_api',
  );
  static String? token;
  static Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> data = const {},
    Uint8List? bytes,
    String? filename,
  ]) async {
    try {
      final uri = Uri.parse('$base/v2.php?action=$action');
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
        response = await http.Response.fromStream(
          await req.send().timeout(const Duration(seconds: 30)),
        );
      } else {
        response = await http
            .post(
              uri,
              headers: {...headers, 'Content-Type': 'application/json'},
              body: jsonEncode(data),
            )
            .timeout(const Duration(seconds: 30));
      }
      final result = jsonDecode(response.body) as Map<String, dynamic>;
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

class ApiError implements Exception {
  ApiError(this.message);
  final String message;
  @override
  String toString() => message;
}
