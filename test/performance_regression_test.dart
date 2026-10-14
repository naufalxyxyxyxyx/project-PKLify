import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pklify/api.dart';
import 'package:pklify/lazy_sections.dart';
import 'package:pklify/main.dart';

const user = <String, dynamic>{
  'id': 3,
  'nama': 'Siswa uji',
  'role': 'siswa',
  'identity': '123',
};
String overview() => jsonEncode({
  'success': true,
  'students': [
    {
      'user': user,
      'placement': null,
      'activities': [],
      'calendar': [],
      'audit': [],
      'grade': null,
    },
  ],
});

void main() {
  tearDown(() => Api.token = null);

  testWidgets('10000 records build only viewport rows and remain scrollable', (
    tester,
  ) async {
    var built = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LazySections(
            sections: [
              LazySection.single(const Text('Riwayat')),
              LazySection(10000, (_, i) {
                built++;
                return SizedBox(height: 60, child: Text('Baris $i'));
              }),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Baris 0'), findsOneWidget);
    expect(built, lessThan(30));
    await tester.drag(find.byType(ListView), const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(built, lessThan(100));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'tab switching reuses overview; explicit refresh fetches new data',
    (tester) async {
      var requests = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              home: Home(user: user, logout: () {}),
            ),
          );
          await tester.pumpAndSettle();
          expect(requests, 1);
          for (final tab in ['Riwayat', 'Nilai', 'Profil', 'Beranda']) {
            await tester.tap(find.text(tab));
            await tester.pumpAndSettle();
          }
          expect(requests, 1);
          await tester.tap(find.byTooltip('Muat ulang'));
          await tester.pumpAndSettle();
          expect(requests, 2);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((_) async {
          requests++;
          return http.Response(overview(), 200);
        }),
      );
    },
  );

  testWidgets('switching tabs during loading does not duplicate requests', (
    tester,
  ) async {
    var requests = 0;
    final pending = Completer<http.Response>();
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            home: Home(user: user, logout: () {}),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('Riwayat'));
        await tester.pump();
        await tester.tap(find.text('Nilai'));
        await tester.pump();
        expect(requests, 1);
        pending.complete(http.Response(overview(), 200));
        await tester.pumpAndSettle();
        expect(find.text('Belum ada nilai akhir'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      () => MockClient((_) {
        requests++;
        return pending.future;
      }),
    );
  });
}
