import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

void main() => runApp(const PklifyApp());

const blue = Color(0xFF2864DC);
const ink = Color(0xFF17212B);
int activeUserId = 0;

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
        onTap: () => journalForm(context),
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

Future<void> loginApi(
  BuildContext context,
  String identity,
  String password,
  bool student,
  ValueChanged<bool> onLogin,
) async {
  if (identity.isEmpty || password.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Isi NIS/NIP dan kata sandi.')),
    );
    return;
  }
  try {
    final response = await http.post(
      Uri.parse('http://10.0.2.2/pklify_api/api.php?action=login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'identity': identity,
        'password': password,
        'role': student ? 'siswa' : 'guru',
      }),
    );
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    if (!context.mounted) return;
    if (result['success'] == true) {
      activeUserId = (result['user']['id'] as num).toInt();
      onLogin(result['user']['role'] == 'siswa');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Login gagal.')),
      );
    }
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tidak terhubung ke API. Pastikan Apache dan MySQL XAMPP aktif.',
          ),
        ),
      );
  }
}

void journalForm(BuildContext context) {
  final judul = TextEditingController();
  final deskripsi = TextEditingController();
  final pelajaran = TextEditingController();
  final kendala = TextEditingController();
  PlatformFile? selectedFile;
  bool sending = false;
  showModalBottomSheet(context: context, isScrollControlled: true, builder: (sheetContext) => StatefulBuilder(builder: (context, setSheetState) => Padding(
    padding: EdgeInsets.fromLTRB(20,20,20,24 + MediaQuery.viewInsetsOf(context).bottom), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Jurnal kegiatan', style: TextStyle(fontSize: 21,fontWeight: FontWeight.w800)), const SizedBox(height: 16),
      TextField(controller: judul, decoration: const InputDecoration(labelText:'Judul kegiatan',border:OutlineInputBorder())), const SizedBox(height:10),
      TextField(controller: deskripsi,maxLines:3,decoration:const InputDecoration(labelText:'Deskripsi kegiatan',border:OutlineInputBorder())), const SizedBox(height:10),
      TextField(controller: pelajaran,decoration:const InputDecoration(labelText:'Hal yang dipelajari',border:OutlineInputBorder())), const SizedBox(height:10),
      TextField(controller: kendala,maxLines:2,decoration:const InputDecoration(labelText:'Kendala dan solusi',border:OutlineInputBorder())), const SizedBox(height:10),
      OutlinedButton.icon(onPressed: () async { final files=await FilePicker.pickFiles(type:FileType.custom,allowedExtensions:['pdf','doc','docx','jpg','jpeg','png']); if(files.isNotEmpty) setSheetState(()=>selectedFile=files.first); }, icon:const Icon(Icons.attach_file), label:Text(selectedFile?.name ?? 'Lampirkan file pendukung')),
      const SizedBox(height:12), FilledButton(onPressed: sending ? null : () async { if(activeUserId == 0 || judul.text.isEmpty || deskripsi.text.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Lengkapi judul dan deskripsi jurnal.')));return;} setSheetState(()=>sending=true); try { final request=http.MultipartRequest('POST',Uri.parse('http://10.0.2.2/pklify_api/upload_jurnal.php')); request.fields.addAll({'siswa_id':'$activeUserId','judul':judul.text,'deskripsi':deskripsi.text,'pelajaran':pelajaran.text,'kendala':kendala.text}); if(selectedFile?.path != null) request.files.add(await http.MultipartFile.fromPath('lampiran',selectedFile!.path!)); final response=await request.send(); final result=jsonDecode(await response.stream.bytesToString()) as Map<String,dynamic>; if(!context.mounted)return; if(result['success']==true){Navigator.pop(sheetContext);ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Jurnal berhasil disimpan ke database.')));}else{ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(result['message'] ?? 'Gagal mengirim jurnal.')));} } catch(_){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Gagal menghubungkan upload jurnal.')));} finally {if(context.mounted)setSheetState(()=>sending=false);} }, style:FilledButton.styleFrom(backgroundColor:blue), child:Text(sending?'Mengirim...':'Kirim jurnal')),
    ]))),));
}

