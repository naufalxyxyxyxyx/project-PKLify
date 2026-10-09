import 'package:flutter/material.dart';

void main() => runApp(const PklifyApp());

const blue = Color(0xFF2864DC);
const ink = Color(0xFF17212B);

class PklifyApp extends StatefulWidget {
  const PklifyApp({super.key});
  @override
  State<PklifyApp> createState() => _PklifyAppState();
}

class _PklifyAppState extends State<PklifyApp> {
  bool? student;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'PKLify',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: blue),
    ),
    home: student == null
        ? Login(onLogin: (role) => setState(() => student = role))
        : Home(student: student!, logout: () => setState(() => student = null)),
  );
}

class Login extends StatefulWidget {
  const Login({super.key, required this.onLogin});
  final ValueChanged<bool> onLogin;
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  bool student = true;
  final id = TextEditingController();
  final password = TextEditingController();
  @override
  void dispose() {
    id.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.route_rounded, color: blue, size: 60),
                const Text(
                  'PKLify',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Selamat datang',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Masuk untuk mencatat dan memantau aktivitas PKL.'),
                const SizedBox(height: 24),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Siswa')),
                    ButtonSegment(value: false, label: Text('Guru')),
                  ],
                  selected: {student},
                  onSelectionChanged: (v) => setState(() => student = v.first),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: id,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: student ? 'NIS' : 'NIP',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Kata sandi',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    if (id.text.isEmpty || password.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Isi NIS/NIP dan kata sandi.'),
                        ),
                      );
                    } else {
                      widget.onLogin(student);
                    }
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Masuk ke PKLify'),
                  style: FilledButton.styleFrom(
                    backgroundColor: blue,
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Versi demo: gunakan NIS/NIP dan kata sandi apa saja.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class Home extends StatefulWidget {
  const Home({super.key, required this.student, required this.logout});
  final bool student;
  final VoidCallback logout;
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final pages = widget.student
        ? [
            const StudentPage(),
            const HistoryPage(),
            const ScorePage(),
            Profile(logout: widget.logout, student: true),
          ]
        : [
            const TeacherPage(),
            const MonitoringPage(),
            const AssessmentPage(),
            Profile(logout: widget.logout, student: false),
          ];
    final labels = widget.student
        ? const ['Beranda', 'Riwayat', 'Nilai', 'Profil']
        : const ['Beranda', 'Monitoring', 'Penilaian', 'Profil'];
    final icons = widget.student
        ? const [
            Icons.home_outlined,
            Icons.history_outlined,
            Icons.workspace_premium_outlined,
            Icons.person_outline,
          ]
        : const [
            Icons.home_outlined,
            Icons.groups_outlined,
            Icons.rule_outlined,
            Icons.person_outline,
          ];
    return Scaffold(
      body: SafeArea(child: pages[index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: List.generate(
          4,
          (i) => NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
        ),
      ),
    );
  }
}

class StudentPage extends StatelessWidget {
  const StudentPage({super.key});
  @override
  Widget build(BuildContext context) => Page(
    title: 'Halo, Andi Pratama',
    children: [
      const BigCard(
        icon: Icons.location_on_outlined,
        title: 'Presensi masuk',
        text: 'Tekan untuk cek lokasi PKL',
      ),
      const SizedBox(height: 22),
      const Text(
        'Aktivitas hari ini',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
      Item(
        icon: Icons.edit_note_outlined,
        title: 'Jurnal kegiatan',
        text: 'Belum diisi',
        onTap: () => form(context, 'Jurnal kegiatan', [
          'Judul kegiatan',
          'Deskripsi kegiatan',
          'Hal yang dipelajari',
        ], 'Kirim jurnal'),
      ),
      Item(
        icon: Icons.camera_alt_outlined,
        title: 'Dokumentasi',
        text: 'Ambil foto dari kamera',
        onTap: () => form(context, 'Dokumentasi kegiatan', [
          'Foto diambil langsung dari kamera',
        ], 'Buka kamera'),
      ),
      Item(
        icon: Icons.assignment_outlined,
        title: 'Pengajuan izin',
        text: 'Kirim alasan dan foto bukti',
        onTap: () => form(context, 'Pengajuan izin', [
          'Jenis izin',
          'Tanggal mulai - selesai',
          'Alasan',
          'Ambil / unggah foto bukti',
        ], 'Kirim pengajuan'),
      ),
    ],
  );
}

class TeacherPage extends StatelessWidget {
  const TeacherPage({super.key});
  @override
  Widget build(BuildContext context) => Page(
    title: 'Halo, Budi Santoso',
    children: const [
      BigCard(
        icon: Icons.groups_2_outlined,
        title: '8 siswa bimbingan',
        text: 'Pantau aktivitas PKL dari satu tempat.',
      ),
      SizedBox(height: 22),
      Text(
        'Perlu perhatian',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
      StaticItem(
        icon: Icons.rate_review_outlined,
        title: 'Jurnal perlu direview',
        text: '2 jurnal menunggu tindakan',
      ),
      StaticItem(
        icon: Icons.assignment_late_outlined,
        title: 'Pengajuan izin',
        text: '1 izin menunggu persetujuan',
      ),
      StaticItem(
        icon: Icons.workspace_premium_outlined,
        title: 'Penilaian akhir',
        text: '3 nilai belum dipublikasikan',
      ),
    ],
  );
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext context) => Page(
    title: 'Riwayat aktivitas',
    children: const [
      StaticItem(
        icon: Icons.login,
        title: 'Presensi masuk',
        text: '08.01 WIB • Lokasi valid',
      ),
      StaticItem(
        icon: Icons.edit_note_outlined,
        title: 'Jurnal kegiatan',
        text: 'Disetujui guru',
      ),
      StaticItem(
        icon: Icons.assignment_outlined,
        title: 'Pengajuan izin',
        text: 'Foto bukti terlampir',
      ),
    ],
  );
}

class ScorePage extends StatelessWidget {
  const ScorePage({super.key});
  @override
  Widget build(BuildContext context) => Page(
    title: 'Nilai akhir saya',
    children: const [
      BigCard(
        icon: Icons.workspace_premium_outlined,
        title: 'Nilai akhir: 89',
        text: 'Kategori: Sangat Baik',
      ),
      SizedBox(height: 18),
      StaticItem(
        icon: Icons.check_circle_outline,
        title: 'Kehadiran',
        text: '90',
      ),
      StaticItem(
        icon: Icons.check_circle_outline,
        title: 'Kedisiplinan',
        text: '85',
      ),
      StaticItem(
        icon: Icons.check_circle_outline,
        title: 'Jurnal & dokumentasi',
        text: '92',
      ),
      StaticItem(
        icon: Icons.feedback_outlined,
        title: 'Catatan guru',
        text: 'Pertahankan kelengkapan jurnal.',
      ),
    ],
  );
}

class MonitoringPage extends StatelessWidget {
  const MonitoringPage({super.key});
  @override
  Widget build(BuildContext context) => Page(
    title: 'Monitoring siswa',
    children: const [
      StaticItem(
        icon: Icons.person_outline,
        title: 'Andi Pratama',
        text: 'Presensi valid • Jurnal terkirim',
      ),
      StaticItem(
        icon: Icons.person_outline,
        title: 'Rina Aulia',
        text: 'Jurnal perlu revisi',
      ),
      StaticItem(
        icon: Icons.person_outline,
        title: 'Dimas Arya',
        text: 'Izin menunggu persetujuan',
      ),
    ],
  );
}

class AssessmentPage extends StatelessWidget {
  const AssessmentPage({super.key});
  @override
  Widget build(BuildContext context) => Page(
    title: 'Penilaian PKL',
    children: const [
      BigCard(
        icon: Icons.rule_outlined,
        title: 'Nilai akhir otomatis',
        text: 'Berdasarkan lima aspek rubrik.',
      ),
      SizedBox(height: 16),
      StaticItem(
        icon: Icons.check_circle_outline,
        title: 'Kehadiran (25%)',
        text: '90',
      ),
      StaticItem(
        icon: Icons.check_circle_outline,
        title: 'Kedisiplinan (20%)',
        text: '85',
      ),
      StaticItem(
        icon: Icons.check_circle_outline,
        title: 'Jurnal & dokumentasi (20%)',
        text: '92',
      ),
    ],
  );
}

class Profile extends StatelessWidget {
  const Profile({super.key, required this.logout, required this.student});
  final VoidCallback logout;
  final bool student;
  @override
  Widget build(BuildContext context) => Page(
    title: 'Profil',
    children: [
      CircleAvatar(
        radius: 38,
        child: Text(student ? 'A' : 'B', style: const TextStyle(fontSize: 30)),
      ),
      const SizedBox(height: 12),
      Text(
        student ? 'Andi Pratama' : 'Budi Santoso',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
      Text(
        student ? 'NIS 2413025070' : 'NIP 1987123456789012',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 28),
      OutlinedButton.icon(
        onPressed: logout,
        icon: const Icon(Icons.logout),
        label: const Text('Keluar dari akun'),
      ),
    ],
  );
}

class Page extends StatelessWidget {
  const Page({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800, color: ink),
      ),
    ),
    body: ListView(padding: const EdgeInsets.all(20), children: children),
  );
}

class BigCard extends StatelessWidget {
  const BigCard({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final String title, text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: blue,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Icon(icon, color: Colors.white, size: 34),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(text, style: const TextStyle(color: Color(0xFFDCE7FF))),
            ],
          ),
        ),
      ],
    ),
  );
}

class Item extends StatelessWidget {
  const Item({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    required this.onTap,
  });
  final IconData icon;
  final String title, text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      leading: Icon(icon, color: blue),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(text),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

class StaticItem extends StatelessWidget {
  const StaticItem({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final String title, text;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: blue),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(text),
    ),
  );
}

void form(
  BuildContext c,
  String title,
  List<String> labels,
  String button,
) => showModalBottomSheet(
  context: c,
  isScrollControlled: true,
  builder: (ctx) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      24 + MediaQuery.viewInsetsOf(ctx).bottom,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          ...labels.map(
            (l) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                maxLines: l == 'Deskripsi kegiatan' || l == 'Alasan' ? 3 : 1,
                decoration: InputDecoration(
                  labelText: l,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: blue),
            child: Text(button),
          ),
        ],
      ),
    ),
  ),
);
