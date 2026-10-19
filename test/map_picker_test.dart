import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:pklify/locations.dart';
import 'package:pklify/map_picker.dart';
import 'package:pklify/place_search.dart';

class TestTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
        ),
      );
}

void main() {
  final response = jsonEncode({
    'features': [
      {
        'geometry': {
          'type': 'Point',
          'coordinates': [106.8, -6.2],
        },
        'properties': {'name': 'Kantor uji', 'city': 'Jakarta'},
      },
      {
        'geometry': {
          'type': 'Point',
          'coordinates': [500, 100],
        },
        'properties': {},
      },
    ],
  });
  test(
    'search preserves longitude/latitude order and caches repeated queries',
    () async {
      var requests = 0;
      final service = PlaceSearch(
        client: MockClient((request) async {
          requests++;
          expect(request.url.queryParameters['limit'], '5');
          return http.Response(response, 200);
        }),
      );
      addTearDown(service.dispose);
      final found = await service.search('Kantor Jakarta');
      expect(found.length, 1);
      expect(found.single.point.latitude, -6.2);
      expect(found.single.point.longitude, 106.8);
      await service.search('kantor jakarta');
      expect(requests, 1);
      await expectLater(service.search('Kantor Bandung'), throwsException);
    },
  );
  test('failed search does not produce a fake location', () async {
    final service = PlaceSearch(
      client: MockClient((_) async => http.Response('', 503)),
    );
    addTearDown(service.dispose);
    await expectLater(service.search('Kantor Jakarta'), throwsException);
  });
  testWidgets(
    'map requires a selected point and search result enables confirmation',
    (tester) async {
      final service = PlaceSearch(
        client: MockClient((_) async => http.Response(response, 200)),
      );
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: MapPickerPage(
            tileProvider: TestTiles(),
            searchService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), 'Kantor Jakarta');
      await tester.tap(find.byTooltip('Cari tempat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kantor uji'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('small phone with keyboard remains scrollable without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: MapPickerPage(tileProvider: TestTiles())),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('picked map point fills form and cancelling keeps it', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LocationForm(
          studentId: 3,
          role: 'siswa',
          version: 0,
          initial: const {},
          pickLocation: (_, initial) async {
            calls++;
            if (calls == 1) {
              expect(initial, isNull);
              return const PickedPlace(
                LatLng(-6.2, 106.8),
                name: 'Kantor peta',
                address: 'Jalan peta',
              );
            }
            expect(initial?.latitude, -6.2);
            return null;
          },
        ),
      ),
    );
    await tester.ensureVisible(find.text('Pilih lokasi di peta'));
    await tester.tap(find.text('Pilih lokasi di peta'));
    await tester.pumpAndSettle();
    expect(find.text('Kantor peta'), findsOneWidget);
    expect(find.text('Jalan peta'), findsOneWidget);
    expect(find.textContaining('Titik tersimpan: -6.2, 106.8'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
    await tester.tap(find.text('Pilih lokasi di peta'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Titik tersimpan: -6.2, 106.8'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
