import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'place_search.dart';

class PickedPlace {
  const PickedPlace(this.point, {this.name = '', this.address = ''});
  final LatLng point;
  final String name, address;
}

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({
    super.key,
    this.initial,
    this.tileProvider,
    this.searchService,
  });
  final LatLng? initial;
  // Injectable providers allow tests without GPS or external map requests.
  final TileProvider? tileProvider;
  final PlaceSearch? searchService;
  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  final controller = MapController();
  final query = TextEditingController();
  late final searcher = widget.searchService ?? PlaceSearch();
  late LatLng center = widget.initial ?? const LatLng(-2.5, 118);
  late double zoom = widget.initial == null ? 5 : 18;
  late bool selected = widget.initial != null;
  bool searching = false, locating = false, tileFailed = false;
  String? error;
  List<PlaceResult> results = [];
  PlaceResult? chosenResult;

  @override
  void dispose() {
    controller.dispose();
    query.dispose();
    if (widget.searchService == null) searcher.dispose();
    super.dispose();
  }

  void select(LatLng p, {PlaceResult? result}) {
    controller.move(p, 18);
    setState(() {
      center = p;
      zoom = 18;
      selected = true;
      chosenResult = result;
      results = [];
      error = null;
    });
  }

  Future<void> search() async {
    if (searching) return;
    FocusScope.of(context).unfocus();
    setState(() {
      searching = true;
      error = null;
      results = [];
    });
    try {
      final found = await searcher.search(query.text);
      if (mounted) {
        setState(() {
          results = found;
          if (found.isEmpty) error = 'Tempat belum ditemukan. Tambahkan nama kota atau pilih titik dengan menggeser peta.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  Future<void> gps() async {
    if (locating) return;
    setState(() {
      locating = true;
      error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw ApiError('Aktifkan lokasi atau pilih titik di peta.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw ApiError(
          'Izin lokasi ditolak. Kamu tetap bisa mencari tempat atau menggeser peta.',
        );
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );
      if (p.isMocked ||
          !p.accuracy.isFinite ||
          p.accuracy <= 0 ||
          p.accuracy > 40) {
        throw ApiError(
          'GPS kurang akurat. Pilih titik kantor secara manual di peta.',
        );
      }
      if (mounted) select(LatLng(p.latitude, p.longitude));
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> link(String url) async {
    try {
      if (!await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank')) {
        throw ApiError('Tautan tidak dapat dibuka.');
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  void tileError() {
    if (tileFailed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !tileFailed) setState(() => tileFailed = true);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pilih tempat PKL di peta')),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: SizedBox(
            height: constraints.maxHeight < 680 ? 680 : constraints.maxHeight,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: query,
                          maxLength: 150,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => search(),
                          decoration: const InputDecoration(
                            labelText: 'Nama instansi atau jalan dan kota',
                            counterText: '',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: searching ? null : search,
                        tooltip: 'Cari tempat',
                        icon: const Icon(Icons.search),
                      ),
                    ],
                  ),
                ),
                if (searching || locating) const LinearProgressIndicator(),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (results.isNotEmpty)
                  SizedBox(
                    height: 140,
                    child: ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (_, i) => ListTile(
                        title: Text(results[i].name),
                        subtitle: Text(
                          results[i].address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () =>
                            select(results[i].point, result: results[i]),
                      ),
                    ),
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: controller,
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: zoom,
                          minZoom: 3,
                          maxZoom: 19,
                          interactionOptions: const InteractionOptions(
                            flags:
                                InteractiveFlag.all & ~InteractiveFlag.rotate,
                          ),
                          onTap: (_, p) => select(p),
                          onPositionChanged: (camera, gesture) {
                            if (!gesture) return;
                            final p = camera.center;
                            setState(() {
                              center = LatLng(
                                p.latitude,
                                ((p.longitude + 180) % 360) - 180,
                              );
                              zoom = camera.zoom;
                              selected = true;
                              // A dragged pin no longer inherits a search result's address.
                              chosenResult = null;
                            });
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: const String.fromEnvironment(
                              'MAP_TILE_URL',
                              defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            ),
                            userAgentPackageName: 'id.pklify.studentplacement',
                            tileProvider: widget.tileProvider,
                            panBuffer: 0,
                            maxNativeZoom: 19,
                            errorTileCallback: (_, _, _) => tileError(),
                          ),
                          if (selected)
                            CircleLayer(
                              circles: [
                                CircleMarker(
                                  point: center,
                                  radius: 40,
                                  useRadiusInMeter: true,
                                  color: Colors.blue.withValues(alpha: .12),
                                  borderColor: Colors.blue,
                                  borderStrokeWidth: 2,
                                ),
                              ],
                            ),
                        ],
                      ),
                      const Center(
                        child: IgnorePointer(
                          child: FractionalTranslation(
                            translation: Offset(0, -.5),
                            child: Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Column(
                          children: [
                            FloatingActionButton.small(
                              heroTag: 'locate',
                              onPressed: locating ? null : gps,
                              tooltip: 'Lokasi saya',
                              child: const Icon(Icons.my_location),
                            ),
                            const SizedBox(height: 8),
                            FloatingActionButton.small(
                              heroTag: 'zoom-in',
                              tooltip: 'Perbesar peta',
                              onPressed: () {
                                final z = (controller.camera.zoom + 1).clamp(
                                  3.0,
                                  19.0,
                                );
                                controller.move(center, z);
                                setState(() => zoom = z);
                              },
                              child: const Icon(Icons.add),
                            ),
                            const SizedBox(height: 8),
                            FloatingActionButton.small(
                              heroTag: 'zoom-out',
                              tooltip: 'Perkecil peta',
                              onPressed: () {
                                final z = (controller.camera.zoom - 1).clamp(
                                  3.0,
                                  19.0,
                                );
                                controller.move(center, z);
                                setState(() => zoom = z);
                              },
                              child: const Icon(Icons.remove),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: ColoredBox(
                          color: Colors.white,
                          child: InkWell(
                            onTap: () =>
                                link('https://www.openstreetmap.org/copyright'),
                            child: const Padding(
                              padding: EdgeInsets.all(5),
                              child: Text(
                                '© OpenStreetMap contributors',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (tileFailed)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Sebagian peta gagal dimuat. Periksa internet dan buka ulang peta sebelum memastikan titik.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        selected ? 'Titik dipilih • radius presensi 40 meter' : 'Cari tempat, ketuk peta, atau gunakan Lokasi saya.',
                      ),
                      const Text(
                        'Geser peta sampai ujung pin berada di pintu masuk/titik presensi. Pastikan bukan lokasi rumah.',
                        style: TextStyle(fontSize: 12),
                      ),
                      TextButton(
                        onPressed: () => link(
                          'https://osmfoundation.org/wiki/Privacy_Policy',
                        ),
                        child: const Text(
                          'Peta: OSM • pencarian: Photon • privasi',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                      FilledButton(
                        onPressed:
                            !selected || zoom < 16 || locating || searching
                            ? null
                            : () => Navigator.pop(
                                context,
                                PickedPlace(
                                  center,
                                  name: chosenResult?.name ?? '',
                                  address: chosenResult?.address ?? '',
                                ),
                              ),
                        child: Text(
                          zoom < 16
                              ? 'Perbesar peta untuk memilih titik tepat'
                              : 'Gunakan lokasi ini',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
