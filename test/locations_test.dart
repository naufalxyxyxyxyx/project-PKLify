import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pklify/api.dart';
import 'package:pklify/locations.dart';
import 'package:pklify/main.dart';

Map<String, dynamic> fixture() => {
  'user': {'id': 3, 'nama': 'Siswa uji'},
  'placement': {
    'tempat': 'Kantor aktif',
    'latitude': -6.2,
    'longitude': 106.8,
    'radius': 40,
  },
  'locations': [
    {
      'id': 5,
      'tempat': 'Kantor usulan',
      'alamat': 'Alamat usulan',
      'latitude': -6.3,
      'longitude': 106.9,
      'status': 'menunggu',
      'reason': 'Pindah penempatan',
      'pengaju': 'Siswa uji',
      'created_at': '2026-10-19',
      'feedback': '',
    },
  ],
};

void main() {
  tearDown(() => Api.token = null);
  testWidgets('student keeps active point and cannot approve pending request', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LocationPage(student: fixture(), role: 'siswa'),
      ),
    );
    expect(find.textContaining('Kantor aktif'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Ajukan lokasi PKL'),
    );
    expect(button.onPressed, isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Setujui lokasi'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('teacher can review pending location with mandatory feedback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LocationPage(student: fixture(), role: 'guru'),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Setujui lokasi'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Konfirmasi'))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), 'Titik sudah sesuai');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Konfirmasi'))
          .onPressed,
      isNotNull,
    );
  });
  testWidgets(
    'location form submits only as proposal with checked coordinates and version',
    (tester) async {
      Map<String, dynamic>? sent;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const MaterialApp(
              home: LocationForm(
                studentId: 3,
                role: 'siswa',
                version: 7,
                initial: {
                  'tempat': 'Kantor',
                  'alamat': 'Jalan uji',
                  'latitude': -6.2,
                  'longitude': 106.8,
                  'reason': 'Pindah tempat',
                },
              ),
            ),
          );
          await tester.drag(find.byType(ListView), const Offset(0, -800));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Kirim pengajuan'),
                )
                .onPressed,
            isNull,
          );
          await tester.tap(find.byType(CheckboxListTile));
          await tester.pump();
          await tester.tap(find.text('Kirim pengajuan'));
          await tester.pumpAndSettle();
        },
        () => MockClient((request) async {
          expect(request.url.queryParameters['action'], 'location_request');
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('{"success":true}', 200);
        }),
      );
      expect(sent?['base_version'], 7);
      expect(sent?['latitude'], -6.2);
      expect(sent?['reason'], 'Pindah tempat');
    },
  );
  testWidgets('invalid coordinates cannot be sent', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LocationForm(
          studentId: 3,
          role: 'siswa',
          version: 0,
          initial: {
            'tempat': 'Kantor',
            'alamat': 'Jalan uji',
            'latitude': 100,
            'longitude': 106.8,
            'reason': 'Uji',
          },
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Kirim pengajuan'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Pilih titik tempat PKL yang valid'),
      findsOneWidget,
    );
  });
  testWidgets('friend password visibility change is retained', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Login(onLogin: (_) {})));
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
      isTrue,
    );
    await tester.tap(find.byTooltip('Lihat kata sandi'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
      isFalse,
    );
  });
}
