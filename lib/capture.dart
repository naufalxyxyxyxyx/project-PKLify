import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class CaptureResult {
  CaptureResult(this.bytes, this.position, this.time);
  final Uint8List bytes;
  final Position? position;
  final DateTime time;
}

class CapturePage extends StatefulWidget {
  const CapturePage({super.key, this.placement, this.locationRequired = true});
  final Map<String, dynamic>? placement;
  final bool locationRequired;
  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage> with WidgetsBindingObserver {
  CameraController? controller;
  Position? position;
  String? error;
  bool busy = false;
  bool starting = false;
  bool _foreground = true;
  bool _restartWhenReady = false;
  Future<void> _cameraReleased = Future.value();

  void releaseCamera() {
    final old = controller;
    controller = null;
    if (old != null) {
      _cameraReleased = _cameraReleased.then((_) => old.dispose());
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initialize();
  }

  Future<void> locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Aktifkan layanan lokasi perangkat.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Izinkan akses lokasi di pengaturan browser/perangkat.');
    }
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 25),
      ),
    );
    if (p.isMocked) throw Exception('Lokasi simulasi tidak diterima.');
    if (mounted) setState(() => position = p);
  }

  Future<void> initialize() async {
    if (!mounted || !_foreground) return;
    if (starting) {
      _restartWhenReady = true;
      return;
    }
    starting = true;
    if (mounted) {
      setState(() {
        busy = true;
        error = null;
      });
    }
    try {
      releaseCamera();
      await _cameraReleased;
      final cameras = await availableCameras();
      if (!mounted || !_foreground) return;
      if (cameras.isEmpty) throw Exception('Kamera tidak tersedia.');
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final next = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      controller = next;
      await next.initialize();
      if (!mounted || !_foreground || controller != next) {
        if (controller == next) releaseCamera();
        return;
      }
      if (widget.locationRequired) await locate();
    } catch (e) {
      if (mounted) setState(() => error = 'Kamera/lokasi belum siap: $e');
    } finally {
      starting = false;
      if (mounted) setState(() => busy = false);
      if (_restartWhenReady && mounted && _foreground) {
        _restartWhenReady = false;
        initialize();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Permission dialogs may be briefly inactive; release when truly hidden.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _foreground = false;
      position = null;
      releaseCamera();
    }
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      if (controller == null) initialize();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _foreground = false;
    releaseCamera();
    super.dispose();
  }

  String get info {
    final p = position;
    if (p == null) {
      return widget.locationRequired
          ? 'Menunggu lokasi terkini…'
          : 'Foto langsung dari kamera';
    }
    final place = widget.placement;
    final distance = place?['latitude'] == null
        ? null
        : Geolocator.distanceBetween(
            p.latitude,
            p.longitude,
            double.parse('${place!['latitude']}'),
            double.parse('${place['longitude']}'),
          );
    return 'Lokasi: ${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}\n'
        'Akurasi: ±${p.accuracy.toStringAsFixed(1)} m\n'
        '${distance == null ? 'Titik PKL belum ditentukan' : 'Jarak: ${distance.toStringAsFixed(1)} m / radius ${place!['radius']} m'}\n'
        'Waktu lokasi: ${p.timestamp.toLocal()}';
  }

  Future<void> capture() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (widget.locationRequired) await locate();
      final camera = controller;
      if (!mounted || !_foreground || camera == null) return;
      final file = await camera.takePicture();
      if (!mounted || !_foreground || controller != camera) return;
      final result = CaptureResult(
        await file.readAsBytes(),
        position,
        DateTime.now(),
      );
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ambil foto langsung')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (controller?.value.isInitialized == true)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 420),
              child: CameraPreview(controller!),
            ),
          ),
        Card(
          child: Padding(padding: const EdgeInsets.all(16), child: Text(info)),
        ),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.red)),
        if (busy) const LinearProgressIndicator(),
        FilledButton.icon(
          onPressed: busy || controller?.value.isInitialized != true
              ? null
              : capture,
          icon: const Icon(Icons.camera_alt),
          label: const Text('Ambil foto & gunakan'),
        ),
        OutlinedButton(
          onPressed: busy ? null : initialize,
          child: const Text('Perbarui kamera dan lokasi'),
        ),
        const Text(
          'Foto diambil langsung. Lokasi akan diperiksa lagi oleh server saat dikirim.',
        ),
      ],
    ),
  );
}
