import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'api.dart';

class PlaceResult {
  const PlaceResult(this.point, this.name, this.address);
  final LatLng point;
  final String name, address;
}

// Deliberate searches only; no autocomplete or reverse geocoding on map drags.
class PlaceSearch {
  PlaceSearch({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  final Map<String, List<PlaceResult>> _cache = {};
  DateTime? _lastRequest;
  bool _inFlight = false;
  static const endpoint = String.fromEnvironment(
    'PLACE_SEARCH_URL',
    defaultValue: 'https://photon.komoot.io/api/',
  );

  Future<List<PlaceResult>> search(String query) async {
    final q = query.trim();
    if (q.length < 3 || q.length > 150) {
      throw ApiError('Isi nama tempat dan kota (3–150 karakter).');
    }
    final key = q.toLowerCase();
    if (_cache.containsKey(key)) return _cache[key]!;
    if (_inFlight ||
        (_lastRequest != null &&
            DateTime.now().difference(_lastRequest!) <
                const Duration(seconds: 2))) {
      throw ApiError('Tunggu sebentar sebelum mencari lagi.');
    }
    _inFlight = true;
    _lastRequest = DateTime.now();
    try {
      final url = Uri.parse(endpoint)
          .replace(queryParameters: {'q': q, 'limit': '5'});
      final response = await _client
          .get(
            url,
            headers: {
              if (!kIsWeb) 'User-Agent': 'PKLify/1.0 (school placement demo)',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw ApiError(
          'Pencarian belum tersedia. Coba lagi nanti atau geser peta.',
        );
      }
      final result = parse(utf8.decode(response.bodyBytes));
      if (_cache.length >= 30) _cache.remove(_cache.keys.first);
      _cache[key] = result;
      return result;
    } on ApiError {
      rethrow;
    } catch (_) {
      throw ApiError(
        'Pencarian gagal. Periksa internet; titik tetap bisa dipilih di peta.',
      );
    } finally {
      _inFlight = false;
    }
  }

  static List<PlaceResult> parse(String body) {
    final data = jsonDecode(body) as Map<String, dynamic>;
    final result = <PlaceResult>[];
    for (final f in data['features'] as List? ?? []) {
      final geo = f['geometry'];
      final c = geo?['coordinates'];
      if (geo?['type'] != 'Point' || c is! List || c.length < 2) continue;
      final lng = double.tryParse('${c[0]}'), lat = double.tryParse('${c[1]}');
      if (lat == null ||
          lng == null ||
          !lat.isFinite ||
          !lng.isFinite ||
          lat.abs() > 85 ||
          lng.abs() > 180) {
        continue;
      }
      final p = f['properties'] as Map? ?? {};
      final address =
          ['street', 'housenumber', 'district', 'city', 'state', 'country']
              .map((k) => '${p[k] ?? ''}')
              .where((s) => s.isNotEmpty)
              .toSet()
              .join(', ');
      result.add(
        PlaceResult(
          LatLng(lat, lng),
          '${p['name'] ?? p['street'] ?? 'Lokasi ditemukan'}',
          address,
        ),
      );
    }
    return result;
  }

  void dispose() => _client.close();
}
