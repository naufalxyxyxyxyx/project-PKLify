@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:sembast_web/sembast_web.dart';
import 'package:pklify/local_backend.dart';

void main() {
  test(
    'Chrome IndexedDB persists progress across connections and accounts',
    () async {
      final name = 'pklify-test-${DateTime.now().microsecondsSinceEpoch}';
      var db = await databaseFactoryWeb.openDatabase(name);
      final clock = DateTime(2026, 10, 21, 9);
      try {
        var local = LocalBackend(open: () async => db, clock: () => clock);
        final student = await local.call('login', {
          'role': 'siswa',
          'identity': '2026101301',
          'password': 'SiswaPkl!2026',
        }, null);
        await local.call(
          'activity',
          {
            'kind': 'jurnal',
            'tanggal': '2026-10-21',
            'title': 'Jurnal browser',
            'body': 'Tes penyimpanan lokal',
          },
          student['token'],
          Uint8List.fromList([37, 80, 68, 70, 45]),
          'jurnal.pdf',
        );
        await db.close();
        db = await databaseFactoryWeb.openDatabase(name);
        local = LocalBackend(open: () async => db, clock: () => clock);
        final teacher = await local.call('login', {
          'role': 'guru',
          'identity': '198701012026101301',
          'password': 'GuruPkl!2026',
        }, null);
        final data = await local.call('overview', {}, teacher['token']);
        expect(data['students'][0]['activities'][0]['title'], 'Jurnal browser');
        expect(data['students'][0]['activities'].length, 1);
        final attachment = await local.call('attachment', {
          'id': data['students'][0]['activities'][0]['id'],
        }, teacher['token']);
        expect(attachment['bytes'], [37, 80, 68, 70, 45]);
      } finally {
        await db.close();
        await databaseFactoryWeb.deleteDatabase(name);
      }
    },
  );
}
