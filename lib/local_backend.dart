import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:latlong2/latlong.dart';
import 'package:sembast/sembast.dart';

import 'api_error.dart';
import 'local_database.dart';

typedef LocalJson = Map<String, dynamic>;

/// Demo only: device owners can inspect/edit local data. Not server security.
class LocalBackend {
  LocalBackend({Future<Database> Function()? open, DateTime Function()? clock})
    : _open = open ?? openLocalDatabase,
      now = clock ?? DateTime.now;
  final Future<Database> Function() _open;
  final DateTime Function() now;
  Future<Database>? _database;
  final _sessions = <String, int>{};
  final _state = StoreRef<String, Map<String, dynamic>>('state').record('v1');
  final _files = StoreRef<int, String>('files');
  String date([DateTime? d]) => (d ?? now()).toIso8601String().substring(0, 10);
  String get stamp => now().toIso8601String();
  String random() =>
      base64UrlEncode(List.generate(24, (_) => Random.secure().nextInt(256)));
  String digest(String salt, String password) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();
  List<LocalJson> rows(LocalJson s, String key) =>
      (s[key] as List).cast<LocalJson>();
  LocalJson publicUser(LocalJson u) => {...u}
    ..remove('password')
    ..remove('salt');
  Never fail(String text) => throw ApiError(text);
  String required(LocalJson d, String key) {
    final value = '${d[key] ?? ''}'.trim();
    if (value.isEmpty || value.length > 10000) fail('Isi $key dengan benar.');
    return value;
  }

  int integer(dynamic v) => int.tryParse('$v') ?? 0;
  double number(dynamic v) {
    final n = double.tryParse('$v');
    if (n == null || !n.isFinite) fail('Angka tidak valid.');
    return n;
  }

  String validDate(dynamic v) {
    final d = DateTime.tryParse('$v');
    if (d == null || date(d) != v) fail('Tanggal tidak valid.');
    return '$v';
  }

  LocalJson? placement(LocalJson s, int id) =>
      rows(s, 'placements').where((p) => p['siswa_id'] == id).firstOrNull;
  void role(LocalJson u, List<String> allowed) {
    if (!allowed.contains(u['role'])) fail('Akses ditolak.');
  }

  void scope(LocalJson s, LocalJson u, int id) {
    if (u['role'] == 'admin' ||
        (u['role'] == 'siswa' && u['id'] == id) ||
        (u['role'] == 'guru' && placement(s, id)?['guru_id'] == u['id'])) {
      return;
    }
    fail('Anda tidak memiliki akses ke siswa ini.');
  }

  LocalJson user(int id, String name, String role, String identity, String pw) {
    final salt = random();
    return {
      'id': id,
      'nama': name,
      'role': role,
      'identity': identity,
      'salt': salt,
      'password': digest(salt, pw),
    };
  }

  LocalJson seed() => {
    'version': 1,
    'next': 4,
    'users': [
      user(1, 'Admin Demo', 'admin', 'admin', 'AdminPkl!2026'),
      user(2, 'Guru Demo', 'guru', '198701012026101301', 'GuruPkl!2026'),
      user(3, 'Siswa Demo', 'siswa', '2026101301', 'SiswaPkl!2026'),
    ],
    'placements': [
      {
        'siswa_id': 3,
        'guru_id': 2,
        'tempat': 'Belum ditentukan',
        'latitude': null,
        'longitude': null,
        'radius': 40,
        'start_date': date(),
        'end_date': date(now().add(const Duration(days: 90))),
        'work_days': '1,2,3,4,5',
        'start_time': '08:00',
        'end_time': '17:00',
        'holidays': '',
      },
    ],
    'activities': <LocalJson>[],
    'locations': <LocalJson>[],
    'grades': <LocalJson>[],
    'audit': <LocalJson>[],
  };
  void audit(LocalJson s, LocalJson u, int? id, String action, String detail) {
    rows(s, 'audit').add({
      'siswa_id': id,
      'nama': u['nama'],
      'action': action,
      'detail': detail,
      'created_at': stamp,
    });
  }

  void unpublish(LocalJson s, int id) {
    for (final g in rows(s, 'grades').where((g) => g['siswa_id'] == id)) {
      g['published_at'] = null;
    }
  }

  bool workday(LocalJson p, String day) =>
      day.compareTo(p['start_date']) >= 0 &&
      day.compareTo(p['end_date']) <= 0 &&
      '${p['work_days']}'
          .split(',')
          .contains('${DateTime.parse(day).weekday}') &&
      !'${p['holidays']}'.split(RegExp(r'[\s,]+')).contains(day);
  List<LocalJson> calendar(LocalJson? p, List<LocalJson> acts) {
    if (p == null) return [];
    final result = <LocalJson>[];
    final last = date().compareTo(p['end_date']) < 0
        ? date()
        : p['end_date'] as String;
    for (
      var d = DateTime.parse(p['start_date']);
      date(d).compareTo(last) <= 0;
      d = d.add(const Duration(days: 1))
    ) {
      final day = date(d);
      if (!workday(p, day)) continue;
      final relevant = acts.where(
        (a) =>
            (a['kind'] == 'masuk' && a['tanggal'] == day) ||
            (a['kind'] == 'izin' &&
                day.compareTo(a['tanggal']) >= 0 &&
                day.compareTo(a['end_date']) <= 0),
      );
      final closed =
          day != date() ||
          now().toIso8601String().substring(11, 16).compareTo(p['end_time']) >=
              0;
      final status =
          relevant.any(
            (a) => a['kind'] == 'masuk' && a['status'] == 'disetujui',
          )
          ? 'hadir'
          : relevant.any(
              (a) => a['kind'] == 'izin' && a['status'] == 'disetujui',
            )
          ? 'izin'
          : relevant.any((a) => a['status'] == 'menunggu')
          ? 'menunggu verifikasi'
          : closed
          ? 'alpa'
          : 'belum presensi';
      result.add({'tanggal': day, 'status': status, 'closed': closed});
    }
    return result.reversed.toList();
  }

  double? score(List<LocalJson> cal) {
    final days = cal
        .where((d) => d['closed'] == true && d['status'] != 'izin')
        .toList();
    if (days.isEmpty || days.any((d) => d['status'] == 'menunggu verifikasi')) {
      return null;
    }
    return double.parse(
      (100 * days.where((d) => d['status'] == 'hadir').length / days.length)
          .toStringAsFixed(2),
    );
  }

  LocalJson overview(LocalJson s, LocalJson u) {
    final students = rows(s, 'users').where(
      (v) =>
          v['role'] == 'siswa' &&
          (u['role'] == 'admin' ||
              (u['role'] == 'siswa' && v['id'] == u['id']) ||
              (u['role'] == 'guru' &&
                  placement(s, v['id'])?['guru_id'] == u['id'])),
    );
    return {
      'user': publicUser(u),
      'server_time': stamp,
      'teachers': u['role'] == 'admin'
          ? rows(
              s,
              'users',
            ).where((v) => v['role'] == 'guru').map(publicUser).toList()
          : [],
      'students': students.map((v) {
        final id = v['id'] as int, p = placement(s, v['id']);
        final acts = rows(
          s,
          'activities',
        ).where((a) => a['siswa_id'] == id).toList().reversed.toList();
        final cal = calendar(p, acts);
        var g = rows(s, 'grades').where((g) => g['siswa_id'] == id).firstOrNull;
        if (u['role'] == 'siswa' && g?['published_at'] == null) g = null;
        return {
          'user': publicUser(v),
          'placement': p == null
              ? null
              : {
                  ...p,
                  'guru': rows(
                    s,
                    'users',
                  ).firstWhere((t) => t['id'] == p['guru_id'])['nama'],
                },
          'activities': acts,
          'locations': rows(
            s,
            'locations',
          ).where((r) => r['siswa_id'] == id).toList().reversed.toList(),
          'calendar': cal,
          'attendance_score': score(cal),
          'grade': g,
          'audit': rows(s, 'audit')
              .where((a) => a['siswa_id'] == id)
              .toList()
              .reversed
              .take(100)
              .toList(),
        };
      }).toList(),
    };
  }

  int version(LocalJson s, int id) => rows(s, 'locations')
      .where((r) => r['siswa_id'] == id && r['status'] == 'disetujui')
      .fold(0, (v, r) => max(v, r['id'] as int));
  void supersede(LocalJson s, int id, String feedback) {
    for (final r in rows(
      s,
      'locations',
    ).where((r) => r['siswa_id'] == id && r['status'] == 'menunggu')) {
      r.addAll({
        'status': 'digantikan',
        'feedback': feedback,
        'reviewed_at': stamp,
      });
    }
  }

  void activate(LocalJson p, LocalJson r) {
    p.addAll({
      for (final k in ['tempat', 'latitude', 'longitude']) k: r[k],
      'radius': 40,
    });
  }

  Future<LocalJson> call(
    String action,
    LocalJson d,
    String? token, [
    Uint8List? bytes,
    String? filename,
  ]) async {
    try {
      final db = await (_database ??= _open());
      return await db.transaction((txn) async {
        final stored = await _state.get(txn);
        final s = stored == null
            ? seed()
            : jsonDecode(jsonEncode(stored)) as LocalJson;
        if (s['version'] != 1) {
          fail('Versi data lokal tidak didukung. Data tidak diubah.');
        }
        if (stored == null) await _state.put(txn, s);
        if (action == 'login') {
          final u = rows(s, 'users')
              .where(
                (u) =>
                    u['identity'] == '${d['identity']}'.trim() &&
                    u['role'] == d['role'],
              )
              .firstOrNull;
          if (u == null ||
              u['password'] != digest(u['salt'], '${d['password']}')) {
            fail('NIS/NIP atau kata sandi salah.');
          }
          final t = random();
          _sessions[t] = u['id'];
          return {'success': true, 'token': t, 'user': publicUser(u)};
        }
        final u = rows(
          s,
          'users',
        ).where((u) => u['id'] == _sessions[token]).firstOrNull;
        if (u == null) fail('Sesi berakhir. Silakan login kembali.');
        if (action == 'logout') {
          _sessions.remove(token);
          return {'success': true};
        }
        if (action == 'overview') return {'success': true, ...overview(s, u)};
        if (action == 'attachment') {
          final a = rows(
            s,
            'activities',
          ).where((a) => a['id'] == integer(d['id'])).firstOrNull;
          if (a == null) fail('Lampiran tidak ditemukan.');
          scope(s, u, a['siswa_id']);
          final content = await _files.record(a['id']).get(txn);
          if (content == null) fail('Lampiran tidak ditemukan.');
          return {'success': true, 'bytes': base64Decode(content)};
        }
        await mutate(s, u, action, d, txn, bytes, filename);
        await _state.put(txn, s);
        return {'success': true};
      });
    } on ApiError {
      rethrow;
    } catch (_) {
      // Never fall back to a new store or report a failed transaction as saved.
      _database = null;
      throw ApiError(
        'Penyimpanan lokal gagal. Periksa ruang perangkat/izin penyimpanan browser. Data tidak dikonfirmasi tersimpan; jangan hapus data browser.',
      );
    }
  }

  Future<void> mutate(
    LocalJson s,
    LocalJson u,
    String action,
    LocalJson d,
    Transaction txn,
    Uint8List? bytes,
    String? filename,
  ) async {
    if (action == 'create_user') {
      role(u, ['admin']);
      final r = required(d, 'role'),
          identity = required(d, 'identity'),
          pw = required(d, 'password');
      if (!['siswa', 'guru'].contains(r) || pw.length < 8) {
        fail('Peran tidak valid atau kata sandi kurang dari 8 karakter.');
      }
      if (rows(s, 'users').any((v) => v['identity'] == identity)) {
        fail('Identitas sudah digunakan.');
      }
      rows(
        s,
        'users',
      ).add(user(s['next']++, required(d, 'nama'), r, identity, pw));
      audit(s, u, null, 'akun_dibuat', identity);
      return;
    }
    if (action == 'placement') {
      role(u, ['admin']);
      final id = integer(d['siswa_id']), guru = integer(d['guru_id']);
      if (!rows(s, 'users').any((v) => v['id'] == id && v['role'] == 'siswa') ||
          !rows(
            s,
            'users',
          ).any((v) => v['id'] == guru && v['role'] == 'guru')) {
        fail('Siswa atau guru tidak valid.');
      }
      final start = validDate(d['start_date']), end = validDate(d['end_date']);
      if (end.compareTo(start) < 0 ||
          DateTime.parse(end).difference(DateTime.parse(start)).inDays > 732) {
        fail('Periode harus berurutan dan maksimal dua tahun.');
      }
      if (!RegExp(r'^[1-7](,[1-7])*$').hasMatch('${d['work_days']}')) {
        fail('Hari kerja tidak valid.');
      }
      final time = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
      if (!time.hasMatch('${d['start_time']}') ||
          !time.hasMatch('${d['end_time']}') ||
          '${d['start_time']}'.compareTo('${d['end_time']}') >= 0) {
        fail('Jam tidak valid.');
      }
      for (final h
          in '${d['holidays'] ?? ''}'
              .split(RegExp(r'[\s,]+'))
              .where((h) => h.isNotEmpty)) {
        validDate(h);
      }
      final reason = required(d, 'reason');
      var p = placement(s, id);
      if (p == null) {
        p = {
          'siswa_id': id,
          'tempat': 'Belum ditentukan',
          'latitude': null,
          'longitude': null,
          'radius': 40,
        };
        rows(s, 'placements').add(p);
      } else if (p['guru_id'] != guru) {
        supersede(s, id, 'Guru pembimbing diganti: $reason');
      }
      p.addAll({
        'guru_id': guru,
        'start_date': start,
        'end_date': end,
        for (final k in ['work_days', 'start_time', 'end_time']) k: d[k],
        'holidays': d['holidays'] ?? '',
      });
      unpublish(s, id);
      audit(s, u, id, 'penempatan_diubah', reason);
      return;
    }
    if ([
      'location_request',
      'location_set',
      'location_review',
    ].contains(action)) {
      role(
        u,
        action == 'location_request'
            ? ['siswa']
            : action == 'location_review'
            ? ['guru']
            : ['guru', 'admin'],
      );
      final r = action == 'location_review'
          ? rows(
              s,
              'locations',
            ).where((r) => r['id'] == integer(d['id'])).firstOrNull
          : null;
      if (action == 'location_review' && r == null) {
        fail('Pengajuan tidak ditemukan.');
      }
      final id = action == 'location_request'
          ? u['id'] as int
          : r?['siswa_id'] as int? ?? integer(d['siswa_id']);
      scope(s, u, id);
      final p = placement(s, id);
      if (p == null) fail('Admin perlu menetapkan guru dan jadwal PKL dahulu.');
      if (integer(r?['base_version'] ?? d['base_version']) != version(s, id)) {
        fail('Lokasi sudah berubah. Muat ulang.');
      }
      if (r != null) {
        if (r['status'] != 'menunggu') fail('Pengajuan sudah diproses.');
        if (!['disetujui', 'perlu_revisi'].contains(d['status'])) {
          fail('Keputusan tidak valid.');
        }
        r.addAll({
          'status': d['status'],
          'feedback': required(d, 'feedback'),
          'pemeriksa': u['nama'],
          'reviewed_at': stamp,
        });
        if (r['status'] == 'disetujui') activate(p, r);
      } else {
        final lat = number(d['latitude']), lng = number(d['longitude']);
        if (lat.abs() > 90 || lng.abs() > 180) fail('Koordinat tidak valid.');
        final direct = action == 'location_set';
        if (!direct &&
            rows(
              s,
              'locations',
            ).any((r) => r['siswa_id'] == id && r['status'] == 'menunggu')) {
          fail('Masih ada pengajuan menunggu.');
        }
        final request = <String, dynamic>{
          'id': s['next']++,
          'siswa_id': id,
          'pengaju': u['nama'],
          'tempat': required(d, 'tempat'),
          'alamat': required(d, 'alamat'),
          'reason': required(d, 'reason'),
          'latitude': lat,
          'longitude': lng,
          'base_version': version(s, id),
          'created_at': stamp,
          'feedback': '',
          'status': direct ? 'disetujui' : 'menunggu',
        };
        if (direct) {
          supersede(s, id, 'Digantikan penetapan baru.');
          activate(p, request);
        }
        rows(s, 'locations').add(request);
      }
      audit(s, u, id, action, '${d['status'] ?? d['tempat']}');
      return;
    }
    if (action == 'activity' || action == 'revise') {
      role(u, ['siswa']);
      final id = u['id'] as int, p = placement(s, u['id']);
      if (p == null) fail('Admin belum mengatur penempatan.');
      final acts = rows(s, 'activities');
      final existing = action == 'revise'
          ? acts
                .where(
                  (a) => a['id'] == integer(d['id']) && a['siswa_id'] == id,
                )
                .firstOrNull
          : null;
      if (action == 'revise' &&
          (existing == null ||
              existing['kind'] != 'jurnal' ||
              existing['status'] != 'perlu_revisi')) {
        fail('Jurnal tidak dapat direvisi.');
      }
      final kind = existing?['kind'] ?? d['kind'];
      if (![
        'masuk',
        'pulang',
        'jurnal',
        'izin',
        'dokumentasi',
      ].contains(kind)) {
        fail('Jenis aktivitas tidak valid.');
      }
      final attendance = ['masuk', 'pulang'].contains(kind);
      final day = attendance
          ? date()
          : validDate(existing?['tanggal'] ?? d['tanggal']);
      String? end;
      double? lat, lng, accuracy, dist;
      var status = kind == 'dokumentasi' ? 'tersimpan' : 'menunggu';
      final title = required(d, 'title'), body = '${d['body'] ?? ''}'.trim();
      if (attendance) {
        if (!workday(p, day)) fail('Hari ini bukan jadwal PKL.');
        lat = number(d['latitude']);
        lng = number(d['longitude']);
        accuracy = number(d['accuracy']);
        if (lat.abs() > 90 ||
            lng.abs() > 180 ||
            accuracy <= 0 ||
            '${d['mocked']}' == 'true') {
          fail('Lokasi tidak valid.');
        }
        final captured = DateTime.tryParse('${d['captured_at']}');
        if (captured == null ||
            now().difference(captured).inSeconds.abs() > 120) {
          fail('Foto/lokasi kedaluwarsa. Ambil ulang.');
        }
        if (p['latitude'] != null) {
          dist = const Distance().as(
            LengthUnit.Meter,
            LatLng(number(p['latitude']), number(p['longitude'])),
            LatLng(lat, lng),
          );
        }
        final valid = dist != null && dist <= 40 && accuracy <= 40;
        if (!valid && (d['exception'] == null || body.length < 5)) {
          fail('Lokasi belum valid. Ajukan kendala dengan alasan.');
        }
        status = valid ? 'disetujui' : 'menunggu';
        if (acts.any(
          (a) =>
              a['siswa_id'] == id && a['kind'] == kind && a['tanggal'] == day,
        )) {
          fail('Presensi sudah tercatat.');
        }
        if (acts.any(
          (a) =>
              a['siswa_id'] == id &&
              a['kind'] == 'izin' &&
              a['status'] == 'disetujui' &&
              day.compareTo(a['tanggal']) >= 0 &&
              day.compareTo(a['end_date']) <= 0,
        )) {
          fail('Tanggal ini memiliki izin.');
        }
        if (kind == 'pulang' &&
            !acts.any(
              (a) =>
                  a['siswa_id'] == id &&
                  a['kind'] == 'masuk' &&
                  a['tanggal'] == day &&
                  ['disetujui', 'menunggu'].contains(a['status']),
            )) {
          fail('Presensi masuk harus lebih dulu.');
        }
      } else {
        if (day.compareTo(p['start_date']) < 0 ||
            day.compareTo(p['end_date']) > 0 ||
            body.isEmpty) {
          fail('Tanggal di luar periode atau keterangan kosong.');
        }
        if (kind == 'izin') {
          end = validDate(d['end_date']);
          if (end.compareTo(day) < 0 || end.compareTo(p['end_date']) > 0) {
            fail('Rentang izin tidak valid.');
          }
          if (acts.any(
            (a) =>
                a['siswa_id'] == id &&
                a['kind'] == 'izin' &&
                ['menunggu', 'disetujui'].contains(a['status']) &&
                day.compareTo(a['end_date']) <= 0 &&
                end!.compareTo(a['tanggal']) >= 0,
          )) {
            fail('Tanggal izin bertumpuk.');
          }
        } else if (day.compareTo(date()) > 0) {
          fail('Aktivitas belum terjadi.');
        }
      }
      final a =
          existing ??
          <String, dynamic>{
            'id': s['next']++,
            'siswa_id': id,
            'created_at': stamp,
            'has_file': false,
            'mime': null,
            'original_name': null,
          };
      if ((attendance || kind == 'izin' || kind == 'dokumentasi') &&
          bytes == null) {
        fail('Foto wajib dilampirkan.');
      }
      if (bytes != null) {
        await saveFile(
          txn,
          a,
          bytes,
          filename,
          attendance || kind == 'izin' || kind == 'dokumentasi',
        );
      }
      a.addAll({
        'kind': kind,
        'tanggal': day,
        'end_date': end,
        'title': title,
        'body': body,
        'learned': d['learned'] ?? '',
        'obstacles': d['obstacles'] ?? '',
        'status': status,
        'feedback': '',
        'latitude': lat,
        'longitude': lng,
        'accuracy': accuracy,
        'distance': dist,
        'updated_at': stamp,
      });
      if (existing == null) acts.add(a);
      if (kind != 'dokumentasi') unpublish(s, id);
      audit(s, u, id, action, '$kind #${a['id']}');
      return;
    }
    if (action == 'review') {
      role(u, ['guru']);
      final a = rows(
        s,
        'activities',
      ).where((a) => a['id'] == integer(d['id'])).firstOrNull;
      if (a == null) fail('Aktivitas tidak ditemukan.');
      final id = a['siswa_id'] as int;
      scope(s, u, id);
      if (a['kind'] == 'dokumentasi' ||
          !(a['kind'] == 'jurnal'
                  ? ['disetujui', 'perlu_revisi']
                  : ['disetujui', 'ditolak'])
              .contains(d['status'])) {
        fail('Keputusan tidak valid.');
      }
      if (d['status'] == 'disetujui') {
        final others = rows(
          s,
          'activities',
        ).where((v) => v['siswa_id'] == id && v['status'] == 'disetujui');
        if (['masuk', 'pulang'].contains(a['kind']) &&
            others.any(
              (v) =>
                  v['kind'] == 'izin' &&
                  '${a['tanggal']}'.compareTo(v['tanggal']) >= 0 &&
                  '${a['tanggal']}'.compareTo(v['end_date']) <= 0,
            )) {
          fail('Tanggal memiliki izin yang disetujui.');
        }
        if (a['kind'] == 'izin' &&
            others.any(
              (v) =>
                  v['kind'] == 'masuk' &&
                  '${v['tanggal']}'.compareTo(a['tanggal']) >= 0 &&
                  '${v['tanggal']}'.compareTo(a['end_date']) <= 0,
            )) {
          fail('Ada presensi hadir pada tanggal izin.');
        }
      }
      a.addAll({
        'status': d['status'],
        'feedback': required(d, 'feedback'),
        'updated_at': stamp,
      });
      unpublish(s, id);
      audit(s, u, id, 'pemeriksaan', '#${a['id']}: ${d['status']}');
      return;
    }
    if (action == 'grade') {
      role(u, ['guru']);
      final id = integer(d['siswa_id']);
      scope(s, u, id);
      final journal = number(d['journal_score']),
          performance = number(d['performance_score']);
      if (journal < 0 ||
          journal > 100 ||
          performance < 0 ||
          performance > 100) {
        fail('Nilai harus 0–100.');
      }
      final p = placement(s, id),
          acts = rows(
            s,
            'activities',
          ).where((a) => a['siswa_id'] == id).toList();
      final attendance = score(calendar(p, acts)),
          publish = d['publish'] == true;
      if (publish &&
          (p == null ||
              now().isBefore(
                DateTime.parse('${p['end_date']}T${p['end_time']}'),
              ))) {
        fail(
          'Nilai akhir diterbitkan setelah PKL selesai. Simpan draf dahulu.',
        );
      }
      if (publish &&
          (attendance == null ||
              acts.any(
                (a) =>
                    ['menunggu', 'perlu_revisi'].contains(a['status']) &&
                    a['kind'] != 'dokumentasi',
              ))) {
        fail('Selesaikan pemeriksaan aktivitas sebelum menerbitkan nilai.');
      }
      rows(s, 'grades').removeWhere((g) => g['siswa_id'] == id);
      rows(s, 'grades').add({
        'siswa_id': id,
        'journal_score': journal,
        'performance_score': performance,
        'attendance_score': attendance,
        'final_score': attendance == null
            ? null
            : double.parse(
                (attendance * .2 + journal * .3 + performance * .5)
                    .toStringAsFixed(2),
              ),
        'note': d['note'] ?? '',
        'published_at': publish ? stamp : null,
        'updated_at': stamp,
      });
      audit(
        s,
        u,
        id,
        publish ? 'nilai_diterbitkan' : 'draf_nilai_disimpan',
        'Jurnal $journal, kinerja $performance',
      );
      return;
    }
    fail('Fitur lokal belum tersedia: $action');
  }

  Future<void> saveFile(
    Transaction txn,
    LocalJson a,
    Uint8List bytes,
    String? name,
    bool photos,
  ) async {
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      fail('Ukuran file harus 1 byte sampai 5 MB.');
    }
    final ext = (name ?? '').split('.').last.toLowerCase();
    final types = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      if (!photos) ...{
        'pdf': 'application/pdf',
        'doc': 'application/msword',
        'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      },
    };
    final mime = types[ext];
    if (mime == null) fail('Jenis lampiran tidak didukung.');
    bool starts(List<int> signature) =>
        bytes.length >= signature.length &&
        List.generate(
          signature.length,
          (i) => bytes[i] == signature[i],
        ).every((v) => v);
    final valid = switch (ext) {
      'jpg' || 'jpeg' => starts([255, 216, 255]),
      'png' => starts([137, 80, 78, 71, 13, 10, 26, 10]),
      'webp' =>
        starts([82, 73, 70, 70]) &&
            bytes.length >= 12 &&
            ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP',
      'pdf' => starts([37, 80, 68, 70]),
      'docx' => starts([80, 75, 3, 4]),
      'doc' => starts([208, 207, 17, 224]),
      _ => false,
    };
    if (!valid) fail('Isi lampiran tidak sesuai jenis file.');
    // Bound demo storage because this small embedded store is held in memory.
    final files = await _files.find(txn);
    final total =
        files
            .where((f) => f.key != a['id'])
            .fold<int>(0, (n, f) => n + f.value.length) +
        ((bytes.length + 2) ~/ 3) * 4;
    if (total > 40 * 1024 * 1024) {
      fail(
        'Penyimpanan lampiran mencapai batas 30 MB. Gunakan file yang lebih kecil.',
      );
    }
    await _files.record(a['id']).put(txn, base64Encode(bytes));
    a.addAll({
      'has_file': true,
      'mime': mime,
      'original_name': (name ?? 'lampiran').split(RegExp(r'[/\\]')).last,
    });
  }
}
