import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'i18n.dart';
import 'location_tools.dart';
import 'session.dart';
import 'spot_flow.dart';
import 'theme.dart';
import 'widgets.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});
  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  static const _dhakaCenter = LatLng(23.7806, 90.4143);

  final _mapController = MapController();
  final searchController = TextEditingController();

  bool mapMode = false;
  bool loading = true;
  bool mapLoading = false;
  bool locating = false;
  bool showSearchArea = false;
  bool _mapReady = false;
  String? err;
  String? locationMessage;
  LocationStatus locationStatus = LocationStatus.unrequested;
  LatLng? userLocation;
  double? userAccuracyM;
  LatLng _mapCenter = _dhakaCenter;
  double _zoom = 13;
  List<Map<String, dynamic>> spots = [];
  List<PlaceSuggestion> suggestions = [];
  Map<String, dynamic>? selectedSpot;
  double maxKm = 12;
  bool? covered;
  double maxMonthly = 15000;
  Timer? _searchDebounce;
  StreamSubscription<Position>? _positionSub;
  int _loadSeq = 0;
  int _suggestSeq = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _locate(centerMap: true, silentFailure: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _positionSub?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Map<String, String> _spotQuery({bool visibleBounds = false}) {
    final origin = userLocation ?? _mapCenter;
    final q = <String, String>{
      'lat': origin.latitude.toStringAsFixed(7),
      'lng': origin.longitude.toStringAsFixed(7),
      'maxKm': maxKm.toStringAsFixed(0),
    };
    if (covered == true) q['covered'] = 'true';
    if (covered == false) q['covered'] = 'false';
    if (maxMonthly < 15000) q['maxMonthly'] = maxMonthly.toStringAsFixed(0);
    if (searchController.text.trim().isNotEmpty) q['q'] = searchController.text.trim();

    if (visibleBounds && _mapReady) {
      final bounds = _mapController.camera.visibleBounds;
      q['north'] = bounds.north.toStringAsFixed(7);
      q['south'] = bounds.south.toStringAsFixed(7);
      q['east'] = bounds.east.toStringAsFixed(7);
      q['west'] = bounds.west.toStringAsFixed(7);
    }
    return q;
  }

  Future<void> _load({bool visibleBounds = false, bool quiet = false}) async {
    final seq = ++_loadSeq;
    setState(() {
      if (quiet) {
        mapLoading = true;
      } else {
        loading = true;
      }
      err = null;
    });
    try {
      final data = await session.api.get('/spots', _spotQuery(visibleBounds: visibleBounds));
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        spots = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        if (selectedSpot != null && !spots.any((s) => s['id'] == selectedSpot!['id'])) {
          selectedSpot = null;
        }
      });
    } catch (e) {
      if (!mounted || seq != _loadSeq) return;
      setState(() => err = e.toString());
    } finally {
      if (mounted && seq == _loadSeq) {
        setState(() {
          loading = false;
          mapLoading = false;
        });
      }
    }
  }

  Future<void> _locate({bool centerMap = false, bool silentFailure = false}) async {
    setState(() {
      locating = true;
      locationStatus = LocationStatus.loading;
      if (!silentFailure) locationMessage = null;
    });
    final result = await getCurrentLocation();
    if (!mounted) return;
    setState(() {
      locating = false;
      locationStatus = result.status;
      userLocation = result.point;
      userAccuracyM = result.accuracyM;
      locationMessage = result.message;
    });

    if (result.point != null) {
      _mapCenter = result.point!;
      _startLocationUpdates();
      if (centerMap && _mapReady) {
        _zoom = 16;
        _mapController.move(result.point!, _zoom);
      }
      await _load(visibleBounds: _mapReady, quiet: true);
    } else if (!silentFailure && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_locationHelp(result.status))));
    }
  }

  void _startLocationUpdates() {
    if (_positionSub != null) return;
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100,
      ),
    ).listen((position) {
      if (!mounted) return;
      setState(() {
        userLocation = LatLng(position.latitude, position.longitude);
        userAccuracyM = position.accuracy;
        locationStatus = LocationStatus.granted;
        locationMessage = null;
      });
    }, onError: (_) {
      _positionSub?.cancel();
      _positionSub = null;
    });
  }

  String _locationHelp(LocationStatus status) {
    switch (status) {
      case LocationStatus.denied:
        return 'Location access helps find nearby parking. You can still search or move the map manually.';
      case LocationStatus.permanentlyDenied:
        return 'Location access is disabled. Enable it in app settings to use current location.';
      case LocationStatus.serviceDisabled:
        return 'Turn on device location services to use current location.';
      case LocationStatus.timeout:
        return 'Location request timed out. Try again or search manually.';
      case LocationStatus.unavailable:
        return 'Current location is temporarily unavailable. Try again or search manually.';
      default:
        return '';
    }
  }

  void _open(Map<String, dynamic> spot) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SpotDetailPage(spotId: spot['id'] as String)));
  }

  void _selectSpot(Map<String, dynamic> spot, {bool moveMap = true}) {
    setState(() {
      selectedSpot = spot;
      mapMode = true;
    });
    final point = LatLng((spot['lat'] as num).toDouble(), (spot['lng'] as num).toDouble());
    if (moveMap && _mapReady) {
      _zoom = math.max(_zoom, 17);
      _mapController.move(point, _zoom);
    }
    _showSpotPreview(spot);
  }

  void _showSpotPreview(Map<String, dynamic> spot) {
    final distance = spot['distanceKm'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(color: Pb.yellow.withOpacity(0.25), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.local_parking_rounded, color: Pb.ink, size: 30),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${spot['area'] ?? 'Parking'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                        const SizedBox(height: 3),
                        Text('${spot['address'] ?? ''}', style: const TextStyle(color: Pb.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _previewChip('৳${spot['hourlyPrice']}/hr'),
                  _previewChip('৳${spot['monthlyPrice']}/mo'),
                  _previewChip(spot['covered'] == true ? 'Covered' : 'Open-air'),
                  if (distance != null) _previewChip('$distance km'),
                ],
              ),
              const SizedBox(height: 16),
              YellowCta(
                label: 'View Details',
                onPressed: () {
                  Navigator.pop(context);
                  _open(spot);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _previewChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Pb.cream, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 320), () => _fetchSuggestions(value));
  }

  Future<void> _fetchSuggestions(String value) async {
    final term = value.trim();
    if (term.length < 2) {
      if (mounted) setState(() => suggestions = []);
      return;
    }
    final seq = ++_suggestSeq;
    final origin = userLocation ?? _mapCenter;
    try {
      final internalRaw = await session.api.get('/spots/suggestions', {
        'q': term,
        'lat': origin.latitude.toStringAsFixed(7),
        'lng': origin.longitude.toStringAsFixed(7),
      });
      final internal = (internalRaw as List)
          .map((e) => PlaceSuggestion.fromParkingJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final external = await searchOsmPlaces(term);
      if (!mounted || seq != _suggestSeq) return;
      final seen = <String>{};
      setState(() {
        suggestions = [...internal, ...external].where((s) {
          final key = '${s.title.toLowerCase()}-${s.point.latitude.toStringAsFixed(4)}-${s.point.longitude.toStringAsFixed(4)}';
          return seen.add(key);
        }).take(10).toList();
      });
    } catch (_) {
      if (mounted && seq == _suggestSeq) setState(() => suggestions = []);
    }
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    FocusScope.of(context).unfocus();
    setState(() {
      suggestions = [];
      searchController.text = suggestion.title;
      _mapCenter = suggestion.point;
      _zoom = suggestion.zoom;
      mapMode = true;
    });
    if (_mapReady) _mapController.move(suggestion.point, suggestion.zoom);
    await _load(visibleBounds: _mapReady, quiet: true);
    if (suggestion.spotId != null) {
      final matching = spots.where((s) => s['id'] == suggestion.spotId).toList();
      if (matching.isNotEmpty) _selectSpot(matching.first, moveMap: false);
    }
  }

  void _onMapMoved() {
    if (!_mapReady) return;
    final camera = _mapController.camera;
    _mapCenter = camera.center;
    _zoom = camera.zoom;
    setState(() => showSearchArea = true);
  }

  Future<void> _searchVisibleArea() async {
    setState(() {
      showSearchArea = false;
      suggestions = [];
    });
    await _load(visibleBounds: true, quiet: true);
  }

  void _showFilters() {
    final i = I18n(session.bn);
    showModalBottomSheet(
      context: context,
      backgroundColor: Pb.cream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(i.t('Filter Parking Spots', 'Filter Parking Spots'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 20),
                  Text(i.t('Covered / Open-air', 'Covered / Open-air'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: ChoiceChip(label: Center(child: Text(i.t('All', 'All'))), selected: covered == null, onSelected: (_) => setSheetState(() => setState(() => covered = null)))),
                      const SizedBox(width: 8),
                      Expanded(child: ChoiceChip(label: Center(child: Text(i.covered)), selected: covered == true, onSelected: (_) => setSheetState(() => setState(() => covered = true)))),
                      const SizedBox(width: 8),
                      Expanded(child: ChoiceChip(label: Center(child: Text(i.openAir)), selected: covered == false, onSelected: (_) => setSheetState(() => setState(() => covered = false)))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Distance Radius: ${maxKm.toStringAsFixed(0)} km', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Slider(value: maxKm, min: 1, max: 30, divisions: 29, activeColor: Pb.yellowDeep, onChanged: (v) => setSheetState(() => setState(() => maxKm = v))),
                  const SizedBox(height: 12),
                  Text('Max Monthly Price: ৳${maxMonthly >= 15000 ? 'Any' : maxMonthly.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Slider(value: maxMonthly, min: 2000, max: 15000, divisions: 13, activeColor: Pb.yellowDeep, onChanged: (v) => setSheetState(() => setState(() => maxMonthly = v))),
                  const SizedBox(height: 24),
                  YellowCta(
                    label: i.t('Apply Filters', 'Apply Filters'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _load(visibleBounds: mapMode && _mapReady);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final i = I18n(session.bn);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Text(i.discover, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => mapMode = !mapMode),
                style: TextButton.styleFrom(
                  backgroundColor: Pb.yellow,
                  foregroundColor: Pb.ink,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: Icon(mapMode ? Icons.view_carousel : Icons.map, size: 18),
                label: Text(mapMode ? i.cards : i.map, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
        _searchBar(i),
        if (err != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('$err\nStart the API on :3001', textAlign: TextAlign.center),
          ),
        if (locationMessage != null && locationStatus != LocationStatus.granted && locationStatus != LocationStatus.loading)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.location_off_outlined, size: 18, color: Pb.muted),
                const SizedBox(width: 8),
                Expanded(child: Text(_locationHelp(locationStatus), style: const TextStyle(color: Pb.muted, fontSize: 12))),
                if (locationStatus == LocationStatus.permanentlyDenied)
                  TextButton(onPressed: Geolocator.openAppSettings, child: const Text('Settings')),
              ],
            ),
          ),
        if (loading) const Expanded(child: Center(child: CircularProgressIndicator(color: Pb.yellow))),
        if (!loading && err == null)
          Expanded(
            child: mapMode
                ? _map()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SpotDeck(spots: spots, onTap: (spot) => _selectSpot(spot)),
                  ),
          ),
      ],
    );
  }

  Widget _searchBar(I18n i) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: TextField(
                    controller: searchController,
                    onChanged: _onSearchChanged,
                    onSubmitted: (_) => _load(visibleBounds: mapMode && _mapReady),
                    decoration: InputDecoration(
                      hintText: i.t('Search area, road, landmark or parking', 'Search area, road, landmark or parking'),
                      hintStyle: const TextStyle(color: Pb.muted, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Pb.muted),
                      suffixIcon: searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                searchController.clear();
                                setState(() => suggestions = []);
                                _load(visibleBounds: mapMode && _mapReady);
                              },
                            ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _showFilters,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: const Icon(Icons.tune, color: Pb.ink),
                ),
              ),
            ],
          ),
          if (suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Pb.ink.withOpacity(0.06))),
              child: Column(
                children: suggestions.map((s) {
                  return ListTile(
                    dense: true,
                    leading: Icon(s.type.startsWith('parking') ? Icons.local_parking_rounded : Icons.place_outlined, color: Pb.yellowDeep),
                    title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(s.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: s.parkingCount == null ? null : Text('${s.parkingCount}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    onTap: () => _selectSuggestion(s),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _map() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _mapCenter,
            initialZoom: _zoom,
            maxZoom: 19,
            minZoom: 5,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            onMapReady: () {
              _mapReady = true;
              _mapController.move(userLocation ?? _mapCenter, userLocation == null ? _zoom : 16);
              _searchVisibleArea();
            },
            onMapEvent: (event) {
              if (event is MapEventMoveEnd || event is MapEventFlingAnimationEnd || event is MapEventScrollWheelZoom) {
                _onMapMoved();
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.parkbangla.mobile',
              maxZoom: 19,
            ),
            CircleLayer(circles: [
              if (userLocation != null && userAccuracyM != null)
                CircleMarker(
                  point: userLocation!,
                  radius: userAccuracyM!.clamp(12, 120).toDouble(),
                  useRadiusInMeter: true,
                  color: Colors.blue.withOpacity(0.12),
                  borderColor: Colors.blue.withOpacity(0.25),
                  borderStrokeWidth: 1,
                ),
            ]),
            MarkerLayer(markers: _markers()),
          ],
        ),
        Positioned(
          top: 12,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedOpacity(
              opacity: showSearchArea ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              child: IgnorePointer(
                ignoring: !showSearchArea,
                child: FilledButton.icon(
                  onPressed: _searchVisibleArea,
                  style: FilledButton.styleFrom(backgroundColor: Pb.ink, foregroundColor: Colors.white),
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Search this area'),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 14,
          bottom: 18,
          child: Column(
            children: [
              FloatingActionButton.small(
                heroTag: 'discover-location',
                backgroundColor: Colors.white,
                foregroundColor: Pb.ink,
                onPressed: locating ? null : () => _locate(centerMap: true),
                child: locating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Pb.yellowDeep))
                    : const Icon(Icons.my_location),
              ),
              const SizedBox(height: 10),
              if (mapLoading) const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: Pb.yellowDeep)),
            ],
          ),
        ),
      ],
    );
  }

  List<Marker> _markers() {
    final markers = <Marker>[];
    if (userLocation != null) {
      markers.add(
        Marker(
          point: userLocation!,
          width: 34,
          height: 34,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 8)],
            ),
          ),
        ),
      );
    }

    for (final group in _clusteredSpots()) {
      if (group.length == 1) {
        final s = group.first;
        final selected = selectedSpot?['id'] == s['id'];
        markers.add(Marker(
          point: LatLng((s['lat'] as num).toDouble(), (s['lng'] as num).toDouble()),
          width: 48,
          height: 48,
          child: GestureDetector(
            onTap: () => _selectSpot(s, moveMap: false),
            child: Icon(Icons.location_on, color: selected ? Pb.ink : Pb.yellowDeep, size: selected ? 48 : 40),
          ),
        ));
      } else {
        final center = _centerOf(group);
        markers.add(Marker(
          point: center,
          width: 52,
          height: 52,
          child: GestureDetector(
            onTap: () {
              _zoom = (_zoom + 2).clamp(5, 19).toDouble();
              _mapController.move(center, _zoom);
            },
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Pb.ink,
                shape: BoxShape.circle,
                border: Border.all(color: Pb.yellow, width: 3),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 10)],
              ),
              child: Text('${group.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            ),
          ),
        ));
      }
    }
    return markers;
  }

  List<List<Map<String, dynamic>>> _clusteredSpots() {
    if (_zoom >= 16.5) return spots.map((s) => [s]).toList();
    final cell = _zoom < 12 ? 0.04 : _zoom < 14 ? 0.018 : 0.006;
    final buckets = <String, List<Map<String, dynamic>>>{};
    for (final spot in spots) {
      final lat = (spot['lat'] as num).toDouble();
      final lng = (spot['lng'] as num).toDouble();
      final key = '${(lat / cell).floor()}:${(lng / cell).floor()}';
      buckets.putIfAbsent(key, () => []).add(spot);
    }
    return buckets.values.toList();
  }

  LatLng _centerOf(List<Map<String, dynamic>> group) {
    var lat = 0.0;
    var lng = 0.0;
    for (final spot in group) {
      lat += (spot['lat'] as num).toDouble();
      lng += (spot['lng'] as num).toDouble();
    }
    return LatLng(lat / group.length, lng / group.length);
  }
}
