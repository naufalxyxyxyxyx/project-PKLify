import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'map_picker.dart';
import 'app_ui.dart';

typedef LocationJson = Map<String, dynamic>;
List<LocationJson> locationRows(dynamic value) => (value as List? ?? [])
    .map((e) => Map<String, dynamic>.from(e as Map))
    .toList();

class LocationPage extends StatefulWidget {
  const LocationPage({super.key, required this.student, required this.role});
  final LocationJson student;
  final String role;
  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  late LocationJson student = widget.student;
  bool busy = false;
  String? error;
  List<LocationJson> get history => locationRows(student['locations']);
  LocationJson? get active {
    for (final r in history) {
      if (r['status'] == 'disetujui') return r;
    }
    return null;
  }

  Future<void> reload() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await Api.call('overview');
      final matches = locationRows(
        result['students'],
      ).where((s) => '${s['user']['id']}' == '${widget.student['user']['id']}');
      if (matches.isEmpty) {
        throw ApiError('Akses siswa berubah. Kembali ke beranda.');
      }
      if (mounted) setState(() => student = matches.first);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> editLocation() async {
    final p = Map<String, dynamic>.from(student['placement'] as Map);
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationForm(
          studentId: student['user']['id'],
          role: widget.role,
          initial: {...p, 'alamat': active?['alamat'] ?? ''},
          version: active?['id'] ?? 0,
        ),
      ),
    );
    if (changed == true && mounted) await reload();
  }

  Future<void> review(LocationJson r, String status) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _ReviewDialog(approve: status == 'disetujui'),
    );
    if (note == null || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Api.call('location_review', {
        'id': r['id'],
        'status': status,
        'feedback': note,
      });
      if (mounted) await reload();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> map(dynamic lat, dynamic lng) async {
    try {
      if (!await launchUrl(
        Uri.https('www.google.com', '/maps/search/', {
          'api': '1',
          'query': '$lat,$lng',
        }),
        webOnlyWindowName: '_blank',
      )) {
        throw ApiError('Peta tidak dapat dibuka.');
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = student['placement'];
    final pending = history.any((r) => r['status'] == 'menunggu');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lokasi PKL'),
        actions: [
          IconButton(
            onPressed: busy ? null : reload,
            tooltip: 'Muat ulang lokasi',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: history.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (busy) const LinearProgressIndicator(),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
                Text(
                  accountLabel(student['user']['nama']),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Lokasi aktif',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  p?['latitude'] == null
                      ? 'Belum ada titik presensi aktif.'
                      : '${p['tempat']}\n${active?['alamat'] ?? ''}\n${p['latitude']}, ${p['longitude']}\nRadius ${p['radius']} meter',
                ),
                if (p?['latitude'] != null)
                  TextButton.icon(
                    onPressed: () => map(p['latitude'], p['longitude']),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Lihat lokasi aktif di peta'),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Pengajuan tidak langsung mengganti lokasi. Lokasi lama tetap berlaku sampai disetujui guru. Titik baru menggunakan radius 40 meter.',
                ),
                if (p == null)
                  const Text(
                    'Minta admin mengatur guru pembimbing dan jadwal dahulu.',
                  ),
                if (pending)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Ada pengajuan menunggu pemeriksaan. Penetapan langsung oleh guru/admin akan menggantikannya.',
                    ),
                  ),
                FilledButton.icon(
                  onPressed:
                      busy || p == null || (widget.role == 'siswa' && pending)
                      ? null
                      : editLocation,
                  icon: const Icon(Icons.edit_location_alt),
                  label: Text(
                    widget.role == 'siswa'
                        ? 'Ajukan lokasi PKL'
                        : 'Tetapkan atau koreksi lokasi',
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Riwayat pengajuan dan perubahan',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (history.isEmpty) const Text('Belum ada pengajuan lokasi.'),
              ],
            );
          }
          final r = history[i - 1];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${r['tempat']} • ${r['status']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${r['alamat']}\n${r['latitude']}, ${r['longitude']}\nAlasan: ${r['reason']}\nPengaju: ${r['pengaju']} • ${r['created_at']}',
                  ),
                  if ('${r['feedback'] ?? ''}'.isNotEmpty)
                    Text(
                      'Catatan: ${r['feedback']}\nPemeriksa: ${r['pemeriksa']} • ${r['reviewed_at']}',
                    ),
                  TextButton(
                    onPressed: () => map(r['latitude'], r['longitude']),
                    child: const Text('Periksa titik di peta'),
                  ),
                  if (widget.role == 'guru' && r['status'] == 'menunggu')
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed: busy ? null : () => review(r, 'disetujui'),
                          child: const Text('Setujui lokasi'),
                        ),
                        OutlinedButton(
                          onPressed: busy
                              ? null
                              : () => review(r, 'perlu_revisi'),
                          child: const Text('Minta perbaikan'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.approve});
  final bool approve;
  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final note = TextEditingController();
  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.approve ? 'Aktifkan lokasi ini?' : 'Minta perbaikan lokasi',
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.approve
              ? 'Pastikan instansi dan titik sesuai penempatan. Lokasi ini akan dipakai untuk presensi berikutnya.'
              : 'Jelaskan bagian yang perlu diperbaiki. Lokasi aktif tidak berubah.',
        ),
        TextField(
          controller: note,
          maxLength: 2000,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Catatan pemeriksaan wajib',
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: note.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, note.text.trim()),
        child: const Text('Konfirmasi'),
      ),
    ],
  );
}

class LocationForm extends StatefulWidget {
  const LocationForm({
    super.key,
    required this.studentId,
    required this.role,
    required this.initial,
    required this.version,
    this.pickLocation,
  });
  final dynamic studentId, version;
  final String role;
  final LocationJson initial;
  final Future<PickedPlace?> Function(BuildContext, LatLng?)? pickLocation;
  @override
  State<LocationForm> createState() => _LocationFormState();
}

class _LocationFormState extends State<LocationForm> {
  late final fields = {
    for (final k in ['tempat', 'alamat', 'latitude', 'longitude', 'reason'])
      k: TextEditingController(text: '${widget.initial[k] ?? ''}'),
  };
  bool busy = false, locating = false, confirmed = false;
  String? error;
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  (double, double) point() {
    final lat = double.tryParse(fields['latitude']!.text.trim());
    final lng = double.tryParse(fields['longitude']!.text.trim());
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180) {
      throw ApiError('Pilih titik tempat PKL yang valid melalui peta.');
    }
    return (lat, lng);
  }

  Future<void> chooseMap() async {
    setState(() {
      locating = true;
      error = null;
    });
    try {
      LatLng? initial;
      try {
        final (lat, lng) = point();
        if (lat.abs() <= 85) initial = LatLng(lat, lng);
      } on ApiError {
        /* New requests start without a pin. */
      }
      final picked = widget.pickLocation != null
          ? await widget.pickLocation!(context, initial)
          : await Navigator.push<PickedPlace>(
              context,
              MaterialPageRoute(
                builder: (_) => MapPickerPage(initial: initial),
              ),
            );
      if (!mounted || picked == null) return;
      fields['latitude']!.text = '${picked.point.latitude}';
      fields['longitude']!.text = '${picked.point.longitude}';
      if ((fields['tempat']!.text.trim().isEmpty ||
              fields['tempat']!.text == 'Belum ditentukan') &&
          picked.name.isNotEmpty) {
        fields['tempat']!.text = picked.name;
      }
      if (fields['alamat']!.text.trim().isEmpty && picked.address.isNotEmpty) {
        fields['alamat']!.text = picked.address;
      }
      setState(() => confirmed = false);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> save() async {
    if (busy || locating || !confirmed) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if ([
        'tempat',
        'alamat',
        'reason',
      ].any((k) => fields[k]!.text.trim().isEmpty)) {
        throw ApiError('Lengkapi nama, alamat, dan alasan.');
      }
      final (lat, lng) = point();
      await Api.call(
        widget.role == 'siswa' ? 'location_request' : 'location_set',
        {
          for (final e in fields.entries) e.key: e.value.text.trim(),
          'latitude': lat,
          'longitude': lng,
          'siswa_id': widget.studentId,
          'base_version': widget.version,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.role == 'siswa' ? 'Ajukan lokasi' : 'Tetapkan lokasi'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          widget.role == 'siswa'
              ? 'Usulan diperiksa guru. Lokasi aktif tidak berubah sebelum disetujui.'
              : 'Lokasi langsung aktif untuk presensi berikutnya. Pengajuan yang masih menunggu akan digantikan. Alasan wajib dicatat.',
        ),
        const Text(
          'Pilih titik tempat PKL pada peta. Koordinat terisi otomatis; radius presensi 40 meter. Pastikan nama dan alamat sesuai pin.',
        ),
        for (final entry in {
          'tempat': 'Nama instansi',
          'alamat': 'Alamat lengkap',
          'reason': 'Alasan pengajuan atau perubahan',
        }.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextField(
              controller: fields[entry.key],
              enabled: !busy && !locating,
              maxLines: ['alamat', 'reason'].contains(entry.key) ? 3 : 1,
              onChanged: (_) => setState(() => confirmed = false),
              decoration: InputDecoration(
                labelText: entry.value,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: busy || locating ? null : chooseMap,
          icon: const Icon(Icons.map_outlined),
          label: const Text('Pilih lokasi di peta'),
        ),
        Text(
          fields['latitude']!.text.isEmpty || fields['longitude']!.text.isEmpty
              ? 'Belum ada titik dipilih.'
              : 'Titik tersimpan: ${fields['latitude']!.text}, ${fields['longitude']!.text}. Buka peta untuk memeriksa atau mengubah.',
        ),
        CheckboxListTile(
          value: confirmed,
          onChanged: busy || locating
              ? null
              : (v) => setState(() => confirmed = v ?? false),
          title: const Text(
            'Saya telah memeriksa bahwa titik dan alamat sesuai tempat PKL.',
          ),
        ),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.red)),
        FilledButton(
          onPressed: busy || locating || !confirmed ? null : save,
          child: Text(
            busy
                ? 'Menyimpan…'
                : widget.role == 'siswa'
                ? 'Kirim pengajuan'
                : 'Aktifkan lokasi',
          ),
        ),
      ],
    ),
  );
}
