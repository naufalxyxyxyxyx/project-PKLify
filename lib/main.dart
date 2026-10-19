import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'capture.dart';
import 'lazy_sections.dart';
import 'uploads.dart';
import 'locations.dart';

typedef Json = Map<String, dynamic>;
List<Json> rows(dynamic v) => (v as List? ?? [])
    .map((e) => e is Json ? e : Map<String, dynamic>.from(e))
    .toList();
String day([DateTime? d]) =>
    (d ?? DateTime.now()).toIso8601String().substring(0, 10);
void main() => runApp(const PklifyApp());
const blue = Color(0xFF2864DC);

class PklifyApp extends StatefulWidget {
  const PklifyApp({super.key});
  @override
  State<PklifyApp> createState() => _AppState();
}

class _AppState extends State<PklifyApp> {
  Json? user;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'PKLify',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: blue),
      scaffoldBackgroundColor: const Color(0xFFF5F7FC),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: user == null
        ? Login(onLogin: (u) => setState(() => user = u))
        : Home(
            user: user!,
            logout: () {
              Api.token = null;
              setState(() => user = null);
            },
          ),
  );
}

class Login extends StatefulWidget {
  const Login({super.key, required this.onLogin});
  final ValueChanged<Json> onLogin;
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final id = TextEditingController(), pw = TextEditingController();
  String role = 'siswa';
  String? error;
  bool busy = false;
  bool showPassword = false;
  @override
  void dispose() {
    id.dispose();
    pw.dispose();
    super.dispose();
  }

  Future<void> login() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final r = await Api.call('login', {
        'identity': id.text.trim(),
        'password': pw.text,
        'role': role,
      });
      if (mounted) {
        Api.token = r['token'];
        widget.onLogin(Map<String, dynamic>.from(r['user']));
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.school_outlined, size: 64, color: blue),
              const Text(
                'PKLify',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
              ),
              const Text(
                'Catat kegiatan. Pantau perkembangan PKL.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'siswa', label: Text('Siswa')),
                  ButtonSegment(value: 'guru', label: Text('Guru')),
                  ButtonSegment(value: 'admin', label: Text('Admin')),
                ],
                selected: {role},
                onSelectionChanged: busy
                    ? null
                    : (s) => setState(() => role = s.first),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: id,
                enabled: !busy,
                decoration: InputDecoration(
                  labelText: role == 'siswa'
                      ? 'NIS'
                      : role == 'guru'
                      ? 'NIP'
                      : 'Username admin',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: pw,
                enabled: !busy,
                obscureText: !showPassword,
                decoration: InputDecoration(
                  labelText: 'Kata sandi',
                  suffixIcon: IconButton(
                    tooltip: showPassword
                        ? 'Sembunyikan kata sandi'
                        : 'Lihat kata sandi',
                    icon: Icon(
                      showPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => showPassword = !showPassword),
                  ),
                ),
                onSubmitted: (_) {
                  if (!busy) login();
                },
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy ? null : login,
                child: Text(busy ? 'Memeriksa akun…' : 'Masuk ke PKLify'),
              ),
              const Text(
                'Gunakan akun yang dibuat admin sekolah.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class Field {
  const Field(
    this.key,
    this.label, {
    this.value = '',
    this.lines = 1,
    this.optional = false,
    this.secret = false,
  });
  final String key, label, value;
  final int lines;
  final bool optional, secret;
}

class DataForm extends StatefulWidget {
  const DataForm({
    super.key,
    required this.title,
    required this.fields,
    required this.submit,
    this.description = '',
  });
  final String title, description;
  final List<Field> fields;
  final Future<void> Function(Json) submit;
  @override
  State<DataForm> createState() => _DataFormState();
}

class _DataFormState extends State<DataForm> {
  late final c = {
    for (final f in widget.fields) f.key: TextEditingController(text: f.value),
  };
  late final secretVisibility = {
    for (final f in widget.fields.where((f) => f.secret)) f.key: false,
  };
  bool busy = false;
  String? error;
  @override
  void dispose() {
    for (final v in c.values) {
      v.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (widget.fields.any(
      (f) => !f.optional && c[f.key]!.text.trim().isEmpty,
    )) {
      setState(() => error = 'Lengkapi kolom wajib.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.submit(c.map((k, v) => MapEntry(k, v.text)));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (widget.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(widget.description),
          ),
        ...widget.fields.map(
          (f) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextField(
              controller: c[f.key],
              enabled: !busy,
              maxLines: f.lines,
              obscureText: f.secret && !(secretVisibility[f.key] ?? false),
              decoration: InputDecoration(
                labelText: f.label,
                suffixIcon: f.secret
                    ? IconButton(
                        tooltip: secretVisibility[f.key] == true
                            ? 'Sembunyikan kata sandi'
                            : 'Lihat kata sandi',
                        icon: Icon(
                          secretVisibility[f.key] == true
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                          () => secretVisibility[f.key] =
                              !(secretVisibility[f.key] ?? false),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.red)),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(busy ? 'Menyimpan…' : 'Simpan'),
        ),
      ],
    ),
  );
}

class Home extends StatefulWidget {
  const Home({super.key, required this.user, required this.logout});
  final Json user;
  final VoidCallback logout;
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  Json? data;
  String? error;
  bool loading = true;
  int index = 0;
  Future<void>? _refreshInFlight;
  DateTime? _lastRefresh;
  List<Json> _students = [];
  List<Json> _activities = [];
  bool get student => widget.user['role'] == 'siswa';
  bool get admin => widget.user['role'] == 'admin';
  List<Json> get students => _students;
  List<Json> get acts => _activities;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh({bool force = true}) {
    if (_refreshInFlight != null) return _refreshInFlight!;
    if (!force &&
        _lastRefresh != null &&
        DateTime.now().difference(_lastRefresh!) <
            const Duration(seconds: 30)) {
      return Future.value();
    }
    return _refreshInFlight = _loadOverview().whenComplete(
      () => _refreshInFlight = null,
    );
  }

  Future<void> _loadOverview() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await Api.call('overview');
      if (!mounted) return;
      final nextStudents = rows(r['students']);
      final nextActivities =
          nextStudents
              .expand(
                (s) =>
                    rows(s['activities'])
                        .map((a) => {...a, 'student_name': s['user']['nama']}),
              )
              .toList()
            ..sort(
              (a, b) => '${b['created_at']}'.compareTo('${a['created_at']}'),
            );
      setState(() {
        data = r;
        _students = nextStudents;
        _activities = nextActivities;
        _lastRefresh = DateTime.now();
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> edit(Widget page) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (changed == true && mounted) {
      // A request started before editing must not hide the newly saved data.
      await _refreshInFlight;
      if (mounted) await refresh();
    }
  }

  Future<void> logout() async {
    try {
      await Api.call('logout');
    } catch (_) {}
    if (mounted) widget.logout();
  }

  Future<void> openLocation(Json s) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPage(student: s, role: widget.user['role']),
      ),
    );
    if (mounted) await refresh();
  }

  Widget tile(String title, String text, {VoidCallback? tap}) => Card(
    child: ListTile(
      title: Text(title),
      subtitle: Text(text),
      trailing: tap == null ? null : const Icon(Icons.chevron_right),
      onTap: tap,
    ),
  );
  Widget heading(String s) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(
      s,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    ),
  );
  Widget banner(String title, String text) => Card(
    color: blue,
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: Colors.white)),
        ],
      ),
    ),
  );
  Widget activityTile(Json a) => tile(
    '${a['title']} • ${a['status']}',
    '${a['student_name'] ?? ''}\n${a['tanggal']} • ${a['kind']}',
    tap: () => edit(
      ActivityDetail(
        activity: a,
        teacher: !student && !admin,
        canRevise: student,
      ),
    ),
  );
  List<Widget> dashboard() {
    final a = acts;
    if (student) {
      final s = students.first;
      final p = s['placement'];
      return [
        banner(
          'Halo, ${widget.user['nama']}',
          p == null
              ? 'Penempatan belum diatur admin.'
              : '${p['tempat']}\nPembimbing: ${p['guru']}',
        ),
        tile(
          'Kehadiran ${rows(s['calendar']).where((r) => r['status'] == 'hadir').length} hari',
          '${a.where((r) => r['kind'] == 'jurnal').length} jurnal • ${a.where((r) => r['kind'] == 'izin').length} pengajuan izin',
        ),
        if (p != null)
          tile(
            'Jadwal PKL',
            '${p['start_date']} — ${p['end_date']}\nHari ${p['work_days']} (1=Senin, 7=Minggu)\n${p['start_time']}–${p['end_time']} • radius ${p['radius']} m',
          ),
        if (p?['latitude'] == null)
          tile(
            'Lokasi belum ditentukan',
            'Ajukan tempat PKL melalui halaman Profil. Sebelum disetujui, presensi diajukan sebagai kendala.',
          ),
        heading('Aktivitas'),
        ...{
          'masuk': 'Presensi masuk',
          'pulang': 'Presensi pulang',
          'jurnal': 'Jurnal kegiatan',
          'izin': 'Pengajuan izin',
          'dokumentasi': 'Dokumentasi kegiatan',
        }.entries.map(
          (e) => tile(
            e.value,
            ['masuk', 'pulang'].contains(e.key)
                ? 'Foto kamera dan lokasi terkini'
                : e.key == 'izin'
                ? 'Alasan, tanggal, dan foto bukti'
                : 'Catat dan simpan kegiatan PKL',
            tap: () => edit(ActivityForm(kind: e.key, placement: p)),
          ),
        ),
      ];
    }
    return [
      banner(
        'Halo, ${widget.user['nama']}',
        admin
            ? 'Kelola akun dan penempatan PKL.'
            : 'Dashboard guru • siswa bimbingan Anda',
      ),
      tile(
        '${students.length} siswa ${admin ? 'terdaftar' : 'bimbingan'}',
        '${a.length} aktivitas tercatat',
      ),
      tile(
        '${a.where((r) => r['kind'] == 'jurnal' && r['status'] == 'menunggu').length} jurnal menunggu',
        'Periksa dan berikan umpan balik',
      ),
      tile(
        '${a.where((r) => r['kind'] == 'izin' && r['status'] == 'menunggu').length} izin menunggu',
        'Periksa foto bukti pengajuan',
      ),
      tile(
        '${a.where((r) => ['masuk', 'pulang'].contains(r['kind']) && r['status'] == 'menunggu').length} kendala presensi',
        'Periksa lokasi, foto, dan alasan siswa',
      ),
      heading('Lokasi PKL siswa'),
      ...students.map(
        (s) => tile(
          s['user']['nama'],
          '${rows(s['locations']).where((r) => r['status'] == 'menunggu').length} pengajuan menunggu • ${s['placement']?['tempat'] ?? 'Belum diatur'}',
          tap: () => openLocation(s),
        ),
      ),
      heading('Aktivitas terbaru'),
      if (a.isEmpty) const Text('Belum ada aktivitas siswa.'),
      ...a.take(5).map(activityTile),
    ];
  }

  Widget history() {
    final calendar = student && students.isNotEmpty
        ? rows(students.first['calendar'])
        : <Json>[];
    final audit = student && students.isNotEmpty
        ? rows(students.first['audit'])
        : <Json>[];
    return LazySections(
      storageKey: 'history',
      sections: [
        if (!student)
          LazySection(students.length, (_, i) {
            final s = students[i];
            return tile(
              '${s['user']['nama']} • ${s['user']['identity']}',
              '${s['placement']?['tempat'] ?? 'Belum ada penempatan'}\n${(s['activities'] as List).length} aktivitas',
              tap: () => edit(StudentDetail(student: s, teacher: !admin)),
            );
          }),
        LazySection.single(
          heading(student ? 'Riwayat aktivitas saya' : 'Aktivitas siswa'),
        ),
        if (acts.isEmpty)
          LazySection.single(const Text('Belum ada aktivitas tersimpan.')),
        LazySection(acts.length, (_, i) => activityTile(acts[i])),
        if (student) ...[
          LazySection.single(heading('Rekap hari kerja')),
          if (calendar.isEmpty)
            LazySection.single(const Text('Belum ada hari PKL yang berjalan.')),
          LazySection(
            calendar.length,
            (_, i) => tile(calendar[i]['tanggal'], calendar[i]['status']),
          ),
          LazySection.single(heading('Catatan perubahan')),
          LazySection(audit.length, (_, i) {
            final r = audit[i];
            return tile(
              r['action'],
              '${r['created_at']} • ${r['nama']}\n${r['detail']}',
            );
          }),
        ],
      ],
    );
  }

  List<Widget> grades() {
    if (student) {
      final g = students.first['grade'];
      return g == null
          ? [
              banner(
                'Belum ada nilai akhir',
                'Guru belum menerbitkan nilai Anda.',
              ),
            ]
          : [
              banner(
                'Nilai akhir: ${g['final_score']}',
                'Diterbitkan ${g['published_at']}',
              ),
              tile('Kehadiran • 20%', '${g['attendance_score']}'),
              tile('Kualitas jurnal • 30%', '${g['journal_score']}'),
              tile('Kinerja dan sikap • 50%', '${g['performance_score']}'),
              tile('Catatan guru', '${g['note']}'),
            ];
    }
    return [
      banner(
        'Penilaian akhir PKL',
        'Guru memberi nilai, sistem menghitung. Terbitkan setelah periode PKL selesai.',
      ),
      const Text(
        'Bobot: kehadiran 20%, jurnal 30%, kinerja dan sikap 50%. Izin disetujui dikeluarkan dari pembagi kehadiran. Hari kerja yang belum selesai belum dihitung.',
      ),
      if (students.isEmpty) const Text('Belum ada siswa bimbingan.'),
      ...students.map(
        (s) => tile(
          s['user']['nama'],
          s['grade'] == null
              ? 'Belum dinilai'
              : s['grade']['published_at'] == null
              ? 'Draf • belum diterbitkan'
              : 'Diterbitkan • ${s['grade']['final_score']}',
          tap: () => edit(GradeForm(student: s)),
        ),
      ),
    ];
  }

  List<Widget> manage() => [
    FilledButton.icon(
      onPressed: () => edit(
        DataForm(
          title: 'Buat akun',
          description: 'Peran siswa memakai NIS; guru memakai NIP. Setelah membuat siswa, atur penempatannya.',
          fields: const [
            Field('role', 'Peran: siswa / guru', value: 'siswa'),
            Field('nama', 'Nama lengkap'),
            Field('identity', 'NIS / NIP'),
            Field('password', 'Kata sandi minimal 8 karakter', secret: true),
          ],
          submit: (d) async {
            await Api.call('create_user', d);
          },
        ),
      ),
      icon: const Icon(Icons.person_add),
      label: const Text('Buat akun siswa / guru'),
    ),
    heading('Penempatan siswa'),
    ...students.map(
      (s) => tile(
        '${s['user']['nama']} • ${s['user']['identity']}',
        '${s['placement']?['tempat'] ?? 'Belum diatur'}',
        tap: () =>
            edit(PlacementForm(student: s, teachers: rows(data?['teachers']))),
      ),
    ),
    heading('Guru terdaftar'),
    ...rows(data?['teachers']).map((t) => tile(t['nama'], t['identity'])),
  ];
  List<Widget> profile() {
    final s = student && students.isNotEmpty ? students.first : null;
    final p = s?['placement'];
    final requests = rows(s?['locations']);
    final latest = requests.isEmpty ? null : requests.first;
    final proposed =
        latest != null &&
        ['menunggu', 'perlu_revisi'].contains(latest['status']);
    final hasActive = p?['latitude'] != null && p?['longitude'] != null;
    final place = proposed
        ? latest['tempat']
        : hasActive
        ? p['tempat']
        : null;
    final status = proposed
        ? latest['status'] == 'menunggu'
              ? 'Menunggu persetujuan guru'
              : 'Perlu perbaikan'
        : hasActive
        ? 'Disetujui'
        : 'Belum mengajukan';
    return [
      banner(
        widget.user['nama'],
        student
            ? 'NIS: ${widget.user['identity']}'
                  '\n${s == null
                      ? 'Data tempat PKL belum dimuat'
                      : place == null
                      ? 'Tempat PKL belum diisi'
                      : 'Tempat PKL: $place'}'
                  '${s == null ? '' : '\nStatus: $status'}'
            : '${widget.user['role']} • ${widget.user['identity']}',
      ),
      if (student && s != null) ...[
        if (proposed && '${latest['alamat'] ?? ''}'.isNotEmpty)
          Text('Alamat pengajuan: ${latest['alamat']}'),
        if (proposed && latest['status'] == 'perlu_revisi')
          Text('Catatan guru: ${latest['feedback'] ?? ''}'),
        if (proposed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              hasActive
                  ? 'Lokasi presensi yang masih aktif: ${p['tempat']}. Pengajuan baru belum menggantikannya.'
                  : 'Tempat yang diajukan belum menjadi titik presensi aktif. Tunggu persetujuan guru.',
            ),
          ),
        FilledButton.icon(
          onPressed: loading ? null : () => openLocation(s),
          icon: const Icon(Icons.business_outlined),
          label: Text(
            latest?['status'] == 'menunggu'
                ? 'Lihat pengajuan tempat PKL'
                : latest?['status'] == 'perlu_revisi'
                ? 'Perbaiki pengajuan tempat PKL'
                : hasActive
                ? 'Detail dan perubahan tempat PKL'
                : 'Ajukan tempat PKL',
          ),
        ),
        if (p == null)
          const Text(
            'Admin perlu menetapkan guru pembimbing dan jadwal agar pengajuan bisa dikirim.',
          ),
      ],
      const SizedBox(height: 12),
      const Text(
        'Data mengikuti akun yang masuk. Muat ulang untuk melihat pembaruan.',
      ),
      OutlinedButton(onPressed: logout, child: const Text('Keluar dari akun')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final labels = admin
        ? ['Beranda', 'Monitoring', 'Kelola', 'Profil']
        : student
        ? ['Beranda', 'Riwayat', 'Nilai', 'Profil']
        : ['Beranda', 'Monitoring', 'Penilaian', 'Profil'];
    final content = index == 3
        ? profile()
        : data == null
        ? <Widget>[]
        : index == 0
        ? dashboard()
        : index == 1
        ? <Widget>[]
        : admin
        ? manage()
        : grades();
    return Scaffold(
      appBar: AppBar(
        title: Text('PKLify • ${labels[index]}'),
        actions: [
          IconButton(
            onPressed: loading ? null : refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: Column(
        children: [
          if (loading) const LinearProgressIndicator(),
          if (error != null)
            MaterialBanner(
              content: Text(error!),
              actions: [
                TextButton(onPressed: refresh, child: const Text('Coba lagi')),
                TextButton(onPressed: logout, child: const Text('Login ulang')),
              ],
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: refresh,
              child: index == 1 && data != null
                  ? history()
                  : ListView(
                      key: PageStorageKey('home-$index'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      children: content,
                    ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) {
          if (v == index) return;
          setState(() => index = v);
          if (v != 3 || student) refresh(force: false);
        },
        destinations: List.generate(
          4,
          (i) => NavigationDestination(
            icon: Icon(
              [
                Icons.home_outlined,
                Icons.history,
                Icons.assignment_outlined,
                Icons.person_outline,
              ][i],
            ),
            label: labels[i],
          ),
        ),
      ),
    );
  }
}

class PlacementForm extends StatelessWidget {
  const PlacementForm({
    super.key,
    required this.student,
    required this.teachers,
  });
  final Json student;
  final List<Json> teachers;
  @override
  Widget build(BuildContext context) {
    final p = student['placement'] as Json? ?? {};
    String v(String k, [String fallback = '']) => '${p[k] ?? fallback}';
    return DataForm(
      title: 'Penempatan ${student['user']['nama']}',
      description:
          'Guru tersedia: ${teachers.map((t) => "ID ${t['id']}: ${t['nama']}").join('; ')}.\nAtur guru dan jadwal di sini. Titik dan alamat diatur melalui menu Lokasi PKL pada beranda. Perubahan guru membatalkan pengajuan lokasi yang menunggu. Perubahan jadwal mengembalikan nilai terbit ke draf.',
      fields: [
        Field(
          'guru_id',
          'ID guru pembimbing',
          value: v(
            'guru_id',
            teachers.isEmpty ? '' : '${teachers.first['id']}',
          ),
        ),
        const Field('reason', 'Alasan pengaturan atau perubahan penempatan'),
        Field(
          'start_date',
          'Tanggal mulai YYYY-MM-DD',
          value: v('start_date', day()),
        ),
        Field(
          'end_date',
          'Tanggal selesai YYYY-MM-DD',
          value: v(
            'end_date',
            day(DateTime.now().add(const Duration(days: 90))),
          ),
        ),
        Field(
          'work_days',
          'Hari kerja 1=Senin … 7=Minggu',
          value: v('work_days', '1,2,3,4,5'),
        ),
        Field(
          'start_time',
          'Jam masuk HH:MM',
          value: v('start_time', '08:00').substring(0, 5),
        ),
        Field(
          'end_time',
          'Jam pulang HH:MM',
          value: v('end_time', '16:00').substring(0, 5),
        ),
        Field(
          'holidays',
          'Tanggal libur YYYY-MM-DD, pisahkan koma',
          value: v('holidays'),
          optional: true,
          lines: 3,
        ),
      ],
      submit: (d) async {
        await Api.call('placement', {...d, 'siswa_id': student['user']['id']});
      },
    );
  }
}

class ActivityForm extends StatefulWidget {
  const ActivityForm({
    super.key,
    required this.kind,
    this.placement,
    this.existing,
  });
  final String kind;
  final Json? placement, existing;
  @override
  State<ActivityForm> createState() => _ActivityFormState();
}

class _ActivityFormState extends State<ActivityForm> {
  bool get attendance => ['masuk', 'pulang'].contains(widget.kind);
  late final title = TextEditingController(
    text:
        widget.existing?['title'] ??
        (attendance ? 'Presensi ${widget.kind}' : ''),
  );
  late final body = TextEditingController(text: widget.existing?['body'] ?? '');
  late final learned = TextEditingController(
    text: widget.existing?['learned'] ?? '',
  );
  late final obstacles = TextEditingController(
    text: widget.existing?['obstacles'] ?? '',
  );
  late final date = TextEditingController(
    text: widget.existing?['tanggal'] ?? day(),
  );
  final end = TextEditingController(text: day());
  Uint8List? bytes;
  String? filename, error;
  CaptureResult? capture;
  bool busy = false, exception = false;
  @override
  void dispose() {
    for (final c in [title, body, learned, obstacles, date, end]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> pick() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: widget.kind == 'izin'
            ? ['jpg', 'jpeg', 'png', 'webp']
            : ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'webp'],
      );
      if (files.isEmpty) return;
      final length = files.first.lengthSync();
      if (length != null && length > maxUploadBytes) {
        throw ApiError('Maksimal ukuran file 5 MB.');
      }
      if (!mounted) return;
      final content = await readUpload(files.first.readAsByteStream());
      if (mounted) {
        setState(() {
          bytes = content;
          filename = files.first.name;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> camera() async {
    final result = await Navigator.push<CaptureResult>(
      context,
      MaterialPageRoute(
        builder: (_) => CapturePage(
          placement: widget.placement,
          locationRequired: attendance,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        capture = result;
        bytes = result.bytes;
        filename = 'foto.jpg';
        error = null;
      });
    }
  }

  Future<void> send() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (title.text.trim().isEmpty) throw ApiError('Judul wajib diisi.');
      if (attendance && capture == null) {
        throw ApiError('Ambil foto dan lokasi terlebih dahulu.');
      }
      if ((attendance ||
              widget.kind == 'izin' ||
              widget.kind == 'dokumentasi') &&
          bytes == null) {
        throw ApiError('Foto wajib dilampirkan.');
      }
      final p = capture?.position;
      await Api.call(
        widget.existing == null ? 'activity' : 'revise',
        {
          'kind': widget.kind,
          'title': title.text,
          'body': body.text,
          'tanggal': date.text,
          'end_date': end.text,
          'learned': learned.text,
          'obstacles': obstacles.text,
          if (widget.existing != null) 'id': widget.existing!['id'],
          if (p != null) ...{
            'latitude': p.latitude,
            'longitude': p.longitude,
            'accuracy': p.accuracy,
            'captured_at': p.timestamp.toUtc().toIso8601String(),
            'mocked': '${p.isMocked}',
          },
          if (exception) 'exception': '1',
        },
        bytes,
        filename,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aktivitas tersimpan. Lihat status di riwayat.'),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(TextEditingController c, String text, [int lines = 1]) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: c,
          enabled: !busy,
          maxLines: lines,
          decoration: InputDecoration(labelText: text),
        ),
      );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        '${widget.existing == null ? 'Kirim' : 'Revisi'} ${widget.kind}',
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (attendance)
          const Text(
            'Foto langsung dari kamera. Waktu ditetapkan server. Radius dan akurasi diperiksa saat dikirim.',
          ),
        field(
          title,
          widget.kind == 'izin'
              ? 'Jenis izin: sakit / keperluan lain'
              : 'Judul',
        ),
        if (!attendance) field(date, 'Tanggal YYYY-MM-DD'),
        if (widget.kind == 'izin') field(end, 'Tanggal selesai YYYY-MM-DD'),
        field(
          body,
          attendance
              ? 'Alasan jika mengajukan kendala'
              : widget.kind == 'izin'
              ? 'Alasan izin'
              : 'Deskripsi kegiatan',
          3,
        ),
        if (widget.kind == 'jurnal') ...[
          field(learned, 'Hal yang dipelajari', 2),
          field(obstacles, 'Kendala dan solusi', 2),
        ],
        if (attendance)
          CheckboxListTile(
            value: exception,
            onChanged: busy ? null : (v) => setState(() => exception = v!),
            title: const Text('Ajukan kendala lokasi kepada guru'),
            subtitle: const Text(
              'Titik belum diatur, di luar radius, atau GPS kurang akurat. Tidak otomatis hadir.',
            ),
          ),
        if (attendance || widget.kind == 'dokumentasi')
          OutlinedButton.icon(
            onPressed: busy ? null : camera,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Buka kamera'),
          )
        else
          OutlinedButton.icon(
            onPressed: busy ? null : pick,
            icon: const Icon(Icons.upload_file),
            label: Text(
              widget.kind == 'izin'
                  ? 'Unggah foto bukti (wajib)'
                  : 'Lampirkan file (opsional)',
            ),
          ),
        if (filename != null)
          Text('Lampiran: $filename • ${(bytes!.length / 1024).round()} KB'),
        if (capture != null) ...[
          Image.memory(capture!.bytes, height: 200, cacheWidth: 640),
          if (capture!.position != null)
            Text(
              'Lokasi ${capture!.position!.latitude}, ${capture!.position!.longitude}\nAkurasi ±${capture!.position!.accuracy.toStringAsFixed(1)} meter',
            ),
        ],
        if (widget.existing?['has_file'] == true && filename == null)
          const Text(
            'Lampiran lama dipertahankan jika tidak memilih file baru.',
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy ? null : send,
          child: Text(busy ? 'Mengirim…' : 'Kirim dan simpan'),
        ),
      ],
    ),
  );
}

class ActivityDetail extends StatefulWidget {
  const ActivityDetail({
    super.key,
    required this.activity,
    required this.teacher,
    this.canRevise = false,
  });
  final Json activity;
  final bool teacher, canRevise;
  @override
  State<ActivityDetail> createState() => _ActivityDetailState();
}

class _ActivityDetailState extends State<ActivityDetail> {
  String? error;
  bool busy = false;
  Future<void> attachment() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final r = await Api.call('attachment', {'id': widget.activity['id']});
      final url = Uri.parse(
        '${Api.base}/v2.php?action=download&ticket=${r['ticket']}',
      );
      if (!mounted) return;
      if ('${widget.activity['mime']}'.startsWith('image/')) {
        final preview = ResizeImage(NetworkImage(url.toString()), width: 1200);
        try {
          await showDialog<void>(
            context: context,
            builder: (ctx) => Dialog(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image(
                      image: preview,
                      errorBuilder: (_, e, s) =>
                          const Text('Foto gagal dimuat. Coba lagi.'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Tutup'),
                    ),
                  ],
                ),
              ),
            ),
          );
        } finally {
          // Download tickets have unique URLs; don't retain each photo in RAM.
          await preview.evict();
        }
      } else if (!await launchUrl(url, webOnlyWindowName: '_blank')) {
        throw ApiError('Tidak dapat membuka lampiran.');
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> review(String status) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DataForm(
          title: 'Keputusan: $status',
          description: 'Alasan wajib diisi dan tersimpan dalam riwayat. Perubahan mengembalikan nilai terbit ke draf.',
          fields: const [Field('feedback', 'Alasan / umpan balik', lines: 3)],
          submit: (d) async {
            await Api.call('review', {
              ...d,
              'id': widget.activity['id'],
              'status': status,
            });
          },
        ),
      ),
    );
    if (changed == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.activity;
    return Scaffold(
      appBar: AppBar(title: Text(a['title'])),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '${a['kind']} • ${a['status']}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            'Tanggal ${a['tanggal']}${a['end_date'] == null ? '' : ' sampai ${a['end_date']}'}\nTercatat ${a['created_at']} WIB',
          ),
          const SizedBox(height: 16),
          Text('${a['body']}'),
          if ('${a['learned']}'.isNotEmpty) Text('Dipelajari: ${a['learned']}'),
          if ('${a['obstacles']}'.isNotEmpty)
            Text('Kendala/solusi: ${a['obstacles']}'),
          if (a['latitude'] != null) ...[
            SelectableText(
              'Lokasi: ${a['latitude']}, ${a['longitude']}\nAkurasi: ±${a['accuracy']} m\nJarak: ${a['distance'] ?? 'belum ditentukan'} m',
            ),
            OutlinedButton(
              onPressed: () => launchUrl(
                Uri.parse(
                  'https://www.google.com/maps/search/?api=1&query=${a['latitude']},${a['longitude']}',
                ),
                webOnlyWindowName: '_blank',
              ),
              child: const Text('Lihat lokasi di peta'),
            ),
          ],
          if (a['has_file'] == true)
            OutlinedButton.icon(
              onPressed: busy ? null : attachment,
              icon: const Icon(Icons.attach_file),
              label: Text('Buka ${a['original_name']}'),
            ),
          if ('${a['feedback']}'.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Catatan guru: ${a['feedback']}'),
              ),
            ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          if (widget.teacher && a['kind'] != 'dokumentasi') ...[
            FilledButton(
              onPressed: () => review('disetujui'),
              child: const Text('Setujui'),
            ),
            OutlinedButton(
              onPressed: () =>
                  review(a['kind'] == 'jurnal' ? 'perlu_revisi' : 'ditolak'),
              child: Text(
                a['kind'] == 'jurnal' ? 'Minta revisi' : 'Tolak / koreksi',
              ),
            ),
          ],
          if (widget.canRevise &&
              a['kind'] == 'jurnal' &&
              a['status'] == 'perlu_revisi')
            FilledButton(
              onPressed: () async {
                final changed = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ActivityForm(kind: 'jurnal', existing: a),
                  ),
                );
                if (changed == true && context.mounted) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Perbaiki jurnal'),
            ),
        ],
      ),
    );
  }
}

class StudentDetail extends StatelessWidget {
  const StudentDetail({
    super.key,
    required this.student,
    required this.teacher,
  });
  final Json student;
  final bool teacher;
  @override
  Widget build(BuildContext context) {
    final calendar = rows(student['calendar']);
    final activities = rows(student['activities']);
    final audit = rows(student['audit']);
    const heading = TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
    return Scaffold(
      appBar: AppBar(title: Text(student['user']['nama'])),
      body: LazySections(
        sections: [
          LazySection.single(
            Text(
              '${student['placement']?['tempat'] ?? 'Penempatan belum ditentukan'}',
            ),
          ),
          LazySection.single(const Text('Rekap hari kerja', style: heading)),
          if (calendar.isEmpty)
            LazySection.single(const Text('Belum ada hari PKL yang berjalan.')),
          LazySection(
            calendar.length,
            (_, i) => ListTile(
              title: Text(calendar[i]['tanggal']),
              trailing: Text(calendar[i]['status']),
            ),
          ),
          LazySection.single(const Text('Aktivitas', style: heading)),
          if (activities.isEmpty)
            LazySection.single(const Text('Belum ada aktivitas.')),
          LazySection(activities.length, (_, i) {
            final a = activities[i];
            return Card(
              child: ListTile(
                title: Text(a['title']),
                subtitle: Text('${a['tanggal']} • ${a['status']}'),
                onTap: () async {
                  final changed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ActivityDetail(activity: a, teacher: teacher),
                    ),
                  );
                  if (changed == true && context.mounted) {
                    Navigator.pop(context, true);
                  }
                },
              ),
            );
          }),
          LazySection.single(const Text('Catatan perubahan', style: heading)),
          LazySection(audit.length, (_, i) {
            final a = audit[i];
            return ListTile(
              title: Text(a['action']),
              subtitle: Text(
                '${a['created_at']} • ${a['nama']}\n${a['detail']}',
              ),
            );
          }),
        ],
      ),
    );
  }
}

class GradeForm extends StatelessWidget {
  const GradeForm({super.key, required this.student});
  final Json student;
  @override
  Widget build(BuildContext context) {
    final g = student['grade'];
    return DataForm(
      title: 'Nilai ${student['user']['nama']}',
      description:
          'Kehadiran otomatis (20%): ${student['attendance_score'] ?? 'belum dapat dihitung'}.\nIsi kualitas jurnal (30%) dan kinerja/sikap (50%) berdasarkan pemeriksaan. Nilai diterbitkan setelah periode selesai dan semua aktivitas diperiksa.',
      fields: [
        Field(
          'journal_score',
          'Kualitas jurnal 0–100',
          value: '${g?['journal_score'] ?? ''}',
        ),
        Field(
          'performance_score',
          'Kinerja dan sikap 0–100',
          value: '${g?['performance_score'] ?? ''}',
        ),
        Field(
          'note',
          'Catatan penilaian',
          value: '${g?['note'] ?? ''}',
          lines: 3,
        ),
        const Field('publication', 'Ketik draf atau terbitkan', value: 'draf'),
      ],
      submit: (d) async {
        if (!['draf', 'terbitkan'].contains(d['publication'])) {
          throw ApiError('Pilih draf atau terbitkan.');
        }
        await Api.call('grade', {
          ...d,
          'siswa_id': student['user']['id'],
          'publish': d['publication'] == 'terbitkan',
        });
      },
    );
  }
}
