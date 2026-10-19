import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pklify/api.dart';
import 'package:pklify/main.dart';
import 'package:pklify/locations.dart';

const student = {
  'id': 3,
  'nama': 'Siswa Percobaan',
  'identity': '123',
  'role': 'siswa',
};

void main() {
  tearDown(() => Api.token = null);
  for (final state in [
    'kosong',
    'menunggu',
    'disetujui',
    'perlu_revisi',
    'pindah',
  ]) {
    testWidgets('student profile shows place state $state', (tester) async {
      final active = ['disetujui', 'pindah'].contains(state);
      final requestStatus = state == 'pindah' ? 'menunggu' : state;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              home: Home(user: student, logout: () {}),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Lokasi PKL dan pengajuan'), findsNothing);
          await tester.tap(find.text('Profil'));
          await tester.pumpAndSettle();
          expect(find.text('Siswa Percobaan'), findsOneWidget);
          expect(find.textContaining('NIS: 123'), findsOneWidget);
          if (state == 'kosong') {
            expect(
              find.textContaining('Tempat PKL belum diisi'),
              findsOneWidget,
            );
            await tester.tap(find.text('Ajukan tempat PKL'));
            await tester.pumpAndSettle();
            expect(find.byType(LocationPage), findsOneWidget);
          } else if (state == 'disetujui') {
            expect(find.textContaining('Tempat PKL: Kantor A'), findsOneWidget);
            expect(find.textContaining('Status: Disetujui'), findsOneWidget);
          } else if (state == 'perlu_revisi') {
            expect(
              find.textContaining('Status: Perlu perbaikan'),
              findsOneWidget,
            );
            expect(find.text('Catatan guru: Periksa titik'), findsOneWidget);
          } else {
            expect(find.textContaining('Tempat PKL: Kantor B'), findsOneWidget);
            expect(
              find.textContaining('Status: Menunggu persetujuan guru'),
              findsOneWidget,
            );
            if (state == 'pindah') {
              expect(
                find.textContaining(
                  'Lokasi presensi yang masih aktif: Kantor A',
                ),
                findsOneWidget,
              );
            } else {
              expect(
                find.textContaining('belum menjadi titik presensi aktif'),
                findsOneWidget,
              );
            }
          }
          expect(tester.takeException(), isNull);
        },
        () => MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': true,
              'students': [
                {
                  'user': student,
                  'placement': {
                    'tempat': active ? 'Kantor A' : 'Belum ditentukan',
                    'guru': 'Guru uji',
                    'latitude': active ? -6.2 : null,
                    'longitude': active ? 106.8 : null,
                    'radius': 40,
                    'start_date': '2026-10-01',
                    'end_date': '2026-12-31',
                    'work_days': '1,2,3,4,5',
                    'start_time': '08:00',
                    'end_time': '16:00',
                  },
                  'locations': state == 'kosong'
                      ? []
                      : [
                          {
                            'id': 1,
                            'tempat': state == 'disetujui'
                                ? 'Kantor A'
                                : 'Kantor B',
                            'alamat': 'Alamat uji',
                            'status': requestStatus,
                            'feedback': 'Periksa titik',
                          },
                        ],
                  'activities': [],
                  'calendar': [],
                  'audit': [],
                  'grade': null,
                },
              ],
            }),
            200,
          ),
        ),
      );
    });
  }
}
