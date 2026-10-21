import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:pklify/api.dart';
import 'package:pklify/local_backend.dart';

void main() {
  late Database db;
  late LocalBackend backend;
  late DateTime clock;
  late String student, teacher, admin;
  Future<String> login(String role, String identity, String password) async =>
      (await backend.call('login', {
            'role': role,
            'identity': identity,
            'password': password,
          }, null))['token']
          as String;
  Future<Map<String, dynamic>> overview(String token) async =>
      ((await backend.call('overview', {}, token))['students'] as List).first
          as Map<String, dynamic>;
  Future<void> journal() async {
    await backend.call('activity', {
      'kind': 'jurnal',
      'tanggal': '2026-10-21',
      'title': 'Belajar Flutter',
      'body': 'Membuat halaman profil',
    }, student);
  }

  setUp(() async {
    clock = DateTime(2026, 10, 21, 9);
    db = await databaseFactoryMemory.openDatabase(
      'test-${DateTime.now().microsecondsSinceEpoch}',
    );
    backend = LocalBackend(open: () async => db, clock: () => clock);
    student = await login('siswa', '2026101301', 'SiswaPkl!2026');
    teacher = await login('guru', '198701012026101301', 'GuruPkl!2026');
    admin = await login('admin', 'admin', 'AdminPkl!2026');
  });
  tearDown(() async => db.close());
  test('new accounts start empty and incorrect login fails', () async {
    final s = await overview(student), t = await overview(teacher);
    expect(s['activities'], isEmpty);
    expect(t['activities'], isEmpty);
    expect(s['grade'], isNull);
    expect(s['attendance_score'], isNull);
    expect(s['placement']['latitude'], isNull);
    await expectLater(
      login('siswa', '2026101301', 'wrong'),
      throwsA(isA<ApiError>()),
    );
    await expectLater(
      backend.call('overview', {}, 'fake'),
      throwsA(isA<ApiError>()),
    );
  });
  test(
    'teacher reviews student journal; revision and logout preserve history',
    () async {
      await journal();
      final a = (await overview(teacher))['activities'][0];
      await expectLater(
        backend.call('review', {
          'id': a['id'],
          'status': 'disetujui',
          'feedback': 'ok',
        }, student),
        throwsA(isA<ApiError>()),
      );
      await backend.call('review', {
        'id': a['id'],
        'status': 'perlu_revisi',
        'feedback': 'Tambahkan detail',
      }, teacher);
      expect(
        (await overview(student))['activities'][0]['feedback'],
        'Tambahkan detail',
      );
      await backend.call('revise', {
        'id': a['id'],
        'title': 'Jurnal baru',
        'body': 'Detail kegiatan',
      }, student);
      expect((await overview(teacher))['activities'][0]['status'], 'menunggu');
      await backend.call('logout', {}, student);
      await expectLater(
        backend.call('overview', {}, student),
        throwsA(isA<ApiError>()),
      );
      student = await login('siswa', '2026101301', 'SiswaPkl!2026');
      expect((await overview(student))['activities'], hasLength(1));
    },
  );
  test(
    'location proposal requires teacher approval and rejects stale changes',
    () async {
      final proposal = {
        'tempat': 'Kantor',
        'alamat': 'Jalan uji',
        'latitude': -6.2,
        'longitude': 106.8,
        'reason': 'Tempat PKL',
        'base_version': 0,
      };
      await backend.call('location_request', proposal, student);
      var s = await overview(student);
      expect(s['placement']['latitude'], isNull);
      await expectLater(
        backend.call('location_request', proposal, student),
        throwsA(isA<ApiError>()),
      );
      await backend.call('location_review', {
        'id': s['locations'][0]['id'],
        'status': 'disetujui',
        'feedback': 'Sesuai',
      }, teacher);
      s = await overview(student);
      expect(s['placement']['latitude'], -6.2);
      expect(s['placement']['radius'], 40);
      await expectLater(
        backend.call('location_request', proposal, student),
        throwsA(isA<ApiError>()),
      );
    },
  );
  test(
    'attachments survive account changes and unsupported content rolls back',
    () async {
      final bytes = Uint8List.fromList([255, 216, 255, 0]);
      final activity = {
        'kind': 'izin',
        'tanggal': '2026-10-21',
        'end_date': '2026-10-21',
        'title': 'Sakit',
        'body': 'Istirahat',
      };
      await backend.call('activity', activity, student, bytes, 'surat.jpg');
      final a = (await overview(teacher))['activities'][0];
      expect(
        (await backend.call('attachment', {'id': a['id']}, teacher))['bytes'],
        bytes,
      );
      await expectLater(
        backend.call(
          'activity',
          {
            'kind': 'dokumentasi',
            'tanggal': '2026-10-21',
            'title': 'Foto',
            'body': 'Bukti',
          },
          student,
          Uint8List.fromList([1, 2]),
          'foto.jpg',
        ),
        throwsA(isA<ApiError>()),
      );
      expect((await overview(student))['activities'], hasLength(1));
    },
  );
  test(
    'camera location checks, duplicate attendance, and final grade publishing',
    () async {
      await backend.call('location_set', {
        'siswa_id': 3,
        'tempat': 'Kantor',
        'alamat': 'Jalan',
        'latitude': -6.2,
        'longitude': 106.8,
        'reason': 'Uji',
        'base_version': 0,
      }, teacher);
      final attendance = {
        'kind': 'masuk',
        'title': 'Masuk',
        'body': '',
        'latitude': -6.2,
        'longitude': 106.8,
        'accuracy': 10,
        'captured_at': clock.toIso8601String(),
        'mocked': 'false',
      };
      final photo = Uint8List.fromList([255, 216, 255, 0]);
      await expectLater(
        backend.call(
          'activity',
          {...attendance, 'latitude': -7.0},
          student,
          photo,
          'foto.jpg',
        ),
        throwsA(isA<ApiError>()),
      );
      await backend.call('activity', attendance, student, photo, 'foto.jpg');
      await expectLater(
        backend.call('activity', attendance, student, photo, 'foto.jpg'),
        throwsA(isA<ApiError>()),
      );
      await backend.call('grade', {
        'siswa_id': 3,
        'journal_score': 80,
        'performance_score': 90,
        'publish': false,
      }, teacher);
      expect((await overview(student))['grade'], isNull);
      await expectLater(
        backend.call('grade', {
          'siswa_id': 3,
          'journal_score': 80,
          'performance_score': 90,
          'publish': true,
        }, teacher),
        throwsA(isA<ApiError>()),
      );
      await backend.call('placement', {
        'siswa_id': 3,
        'guru_id': 2,
        'start_date': '2026-10-21',
        'end_date': '2026-10-21',
        'start_time': '08:00',
        'end_time': '17:00',
        'work_days': '1,2,3,4,5',
        'reason': 'Uji selesai',
      }, admin);
      clock = DateTime(2026, 10, 21, 18);
      await backend.call('grade', {
        'siswa_id': 3,
        'journal_score': 80,
        'performance_score': 90,
        'publish': true,
      }, teacher);
      expect((await overview(student))['grade']['final_score'], 89);
      await journal();
      expect((await overview(student))['grade'], isNull);
    },
  );
  test('unassigned accounts cannot see or change another student', () async {
    await backend.call('create_user', {
      'role': 'guru',
      'nama': 'Guru lain',
      'identity': 'guru2',
      'password': 'Password123',
    }, admin);
    final other = await login('guru', 'guru2', 'Password123');
    expect((await backend.call('overview', {}, other))['students'], isEmpty);
    await journal();
    final id = (await overview(student))['activities'][0]['id'];
    await expectLater(
      backend.call('review', {
        'id': id,
        'status': 'disetujui',
        'feedback': 'ok',
      }, other),
      throwsA(isA<ApiError>()),
    );
  });
  test(
    'file-backed data survives closing and reopening, without reseeding',
    () async {
      final temp = await Directory.systemTemp.createTemp('pklify-local-test-');
      final path = '${temp.path}/demo.db';
      try {
        var disk = await databaseFactoryIo.openDatabase(path);
        backend = LocalBackend(open: () async => disk, clock: () => clock);
        student = await login('siswa', '2026101301', 'SiswaPkl!2026');
        await journal();
        await disk.close();
        disk = await databaseFactoryIo.openDatabase(path);
        backend = LocalBackend(open: () async => disk, clock: () => clock);
        teacher = await login('guru', '198701012026101301', 'GuruPkl!2026');
        expect((await overview(teacher))['activities'], hasLength(1));
        await disk.close();
      } finally {
        await temp.delete(recursive: true);
      }
    },
  );
}
