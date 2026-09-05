import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool availableNow = false;
  bool verifiedOnly = false;
  bool savedOnly = false;
  bool showRenterTips = false;
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
  List<String> recentSearches = [];
  Map<String, dynamic>? selectedSpot;
  double maxKm = 12;
  bool? covered;
  String vehicleSize = 'any';
  String accessType = 'any';
  String priceMode = 'monthly';
  double maxMonthly = 15000;
  double maxDaily = 1500;
  double maxHourly = 250;
  Set<String> favoriteSpotIds = {};
  Timer? _searchDebounce;
  StreamSubscription<Position>? _positionSub;
  int _loadSeq = 0;
  int _suggestSeq = 0;

  List<Map<String, dynamic>> get _visibleSpots =>
      savedOnly ? spots.where((spot) => favoriteSpotIds.contains(spot['id']?.toString())).toList() : spots;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _loadRenterTips();
    _load();
    _loadFavorites();
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
    if (vehicleSize != 'any') q['vehicleSize'] = vehicleSize;
    if (accessType != 'any') q['accessType'] = accessType;
    if (verifiedOnly) q['verifiedOnly'] = 'true';
    if (priceMode == 'hourly' && maxHourly < 250) q['maxHourly'] = maxHourly.toStringAsFixed(0);
    if (priceMode == 'daily' && maxDaily < 1500) q['maxDaily'] = maxDaily.toStringAsFixed(0);
    if (priceMode == 'monthly' && maxMonthly < 15000) q['maxMonthly'] = maxMonthly.toStringAsFixed(0);
    if (availableNow) {
      final now = DateTime.now();
      final later = now.add(const Duration(hours: 1));
      q['startDate'] = _dateParam(now);
      q['endDate'] = _dateParam(later);
      q['startTime'] = _timeParam(now);
      q['endTime'] = _timeParam(later);
    }
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

  String _dateParam(DateTime value) => value.toIso8601String().split('T').first;

  String _timeParam(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

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

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => recentSearches = prefs.getStringList('recent_searches') ?? []);
  }

  Future<void> _loadRenterTips() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => showRenterTips = prefs.getBool('renter_tips_seen') != true);
  }

  Future<void> _dismissRenterTips() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('renter_tips_seen', true);
    if (mounted) setState(() => showRenterTips = false);
  }

  Future<void> _loadFavorites() async {
    if (session.api.token == null) return;
    try {
      final data = await session.api.get('/me/favorites');
      if (!mounted || data is! List) return;
      setState(() {
        favoriteSpotIds = data
            .map((raw) => Map<String, dynamic>.from(raw as Map))
            .map((fav) => Map<String, dynamic>.from(fav['spot'] as Map? ?? {})['id']?.toString())
            .whereType<String>()
            .toSet();
      });
    } catch (_) {}
  }

  Future<void> _toggleFavorite(Map<String, dynamic> spot) async {
    if (session.api.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to save spots.')));
      return;
    }
    final id = spot['id']?.toString();
    if (id == null) return;
    final saved = favoriteSpotIds.contains(id);
    setState(() {
      if (saved) {
        favoriteSpotIds.remove(id);
      } else {
        favoriteSpotIds.add(id);
      }
    });
    try {
      if (saved) {
        await session.api.delete('/me/favorites/$id');
      } else {
        await session.api.post('/me/favorites/$id', {});
      }
    } catch (e) {
      setState(() {
        if (saved) {
          favoriteSpotIds.add(id);
        } else {
          favoriteSpotIds.remove(id);
        }
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update saved spot: $e')));
    }
  }

  Future<void> _saveRecentSearch(String value) async {
    final term = value.trim();
    if (term.length < 2) return;
    final next = [term, ...recentSearches.where((item) => item.toLowerCase() != term.toLowerCase())].take(6).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_searches', next);
    if (mounted) setState(() => recentSearches = next);
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
    final spotId = spot['id']?.toString();
    final saved = spotId != null && favoriteSpotIds.contains(spotId);
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
                  IconButton(
                    tooltip: saved ? 'Remove saved spot' : 'Save spot',
                    onPressed: () {
                      Navigator.pop(context);
                      _toggleFavorite(spot);
                    },
                    icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
                    color: Pb.ink,
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
                  _previewChip('${spot['accessType'] ?? 'Access'}'),
                  _previewChip(spot['verified'] == true ? 'Verified' : '${spot['verifiedStatus'] ?? 'Unverified'}'),
                  if (distance != null) _previewChip('$distance km'),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.navigation_outlined, size: 18),
                      label: const Text('Navigate'),
                      onPressed: () {
                        final point = LatLng((spot['lat'] as num).toDouble(), (spot['lng'] as num).toDouble());
                        openExternalNavigation(point);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: YellowCta(
                      label: 'View Details',
                      onPressed: () {
                        Navigator.pop(context);
                        _open(spot);
                      },
                    ),
                  ),
                ],
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
    await _saveRecentSearch(suggestion.title);
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
      isScrollControlled: true,
      backgroundColor: Pb.cream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
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
                      Expanded(child: _segmentChip(i.t('All', 'All'), covered == null, () => setSheetState(() => setState(() => covered = null)))),
                      const SizedBox(width: 8),
                      Expanded(child: _segmentChip(i.covered, covered == true, () => setSheetState(() => setState(() => covered = true)))),
                      const SizedBox(width: 8),
                      Expanded(child: _segmentChip(i.openAir, covered == false, () => setSheetState(() => setState(() => covered = false)))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Vehicle size', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _filterChip('Any', vehicleSize == 'any', () => setSheetState(() => setState(() => vehicleSize = 'any'))),
                      _filterChip('Sedan', vehicleSize == 'sedan', () => setSheetState(() => setState(() => vehicleSize = 'sedan'))),
                      _filterChip('SUV', vehicleSize == 'suv', () => setSheetState(() => setState(() => vehicleSize = 'suv'))),
                      _filterChip('Microbus', vehicleSize == 'microbus', () => setSheetState(() => setState(() => vehicleSize = 'microbus'))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Access type', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _filterChip('Any', accessType == 'any', () => setSheetState(() => setState(() => accessType = 'any'))),
                      _filterChip('Guard', accessType == 'GUARD', () => setSheetState(() => setState(() => accessType = 'GUARD'))),
                      _filterChip('Gate code', accessType == 'GATE_CODE', () => setSheetState(() => setState(() => accessType = 'GATE_CODE'))),
                      _filterChip('Remote', accessType == 'REMOTE', () => setSheetState(() => setState(() => accessType = 'REMOTE'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Verified only', style: TextStyle(fontWeight: FontWeight.w700)),
                    value: verifiedOnly,
                    activeColor: Pb.ink,
                    activeTrackColor: Pb.yellow,
                    onChanged: (v) => setSheetState(() => setState(() => verifiedOnly = v)),
                  ),
                  const SizedBox(height: 12),
                  Text('Distance Radius: ${maxKm.toStringAsFixed(0)} km', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Slider(value: maxKm, min: 1, max: 30, divisions: 29, activeColor: Pb.yellowDeep, onChanged: (v) => setSheetState(() => setState(() => maxKm = v))),
                  const SizedBox(height: 12),
                  const Text('Price focus', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _segmentChip('Hourly', priceMode == 'hourly', () => setSheetState(() => setState(() => priceMode = 'hourly')))),
                      const SizedBox(width: 8),
                      Expanded(child: _segmentChip('Daily', priceMode == 'daily', () => setSheetState(() => setState(() => priceMode = 'daily')))),
                      const SizedBox(width: 8),
                      Expanded(child: _segmentChip('Monthly', priceMode == 'monthly', () => setSheetState(() => setState(() => priceMode = 'monthly')))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (priceMode == 'hourly') ...[
                    Text('Max Hourly Price: ৳${maxHourly >= 250 ? 'Any' : maxHourly.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Slider(value: maxHourly, min: 50, max: 250, divisions: 8, activeColor: Pb.yellowDeep, onChanged: (v) => setSheetState(() => setState(() => maxHourly = v))),
                  ] else if (priceMode == 'daily') ...[
                    Text('Max Daily Price: ৳${maxDaily >= 1500 ? 'Any' : maxDaily.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Slider(value: maxDaily, min: 200, max: 1500, divisions: 13, activeColor: Pb.yellowDeep, onChanged: (v) => setSheetState(() => setState(() => maxDaily = v))),
                  ] else ...[
                    Text('Max Monthly Price: ৳${maxMonthly >= 15000 ? 'Any' : maxMonthly.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Slider(value: maxMonthly, min: 2000, max: 15000, divisions: 13, activeColor: Pb.yellowDeep, onChanged: (v) => setSheetState(() => setState(() => maxMonthly = v))),
                  ],
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Available now', style: TextStyle(fontWeight: FontWeight.w700)),
                    value: availableNow,
                    activeColor: Pb.ink,
                    activeTrackColor: Pb.yellow,
                    onChanged: (v) => setSheetState(() => setState(() => availableNow = v)),
                  ),
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

  Widget _filterChip(String label, bool selected, VoidCallback onSelected) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: Pb.yellow,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(color: Pb.ink, fontWeight: selected ? FontWeight.w900 : FontWeight.w600),
      side: BorderSide(color: selected ? Pb.yellowDeep : Pb.ink.withOpacity(0.12)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (_) => onSelected(),
    );
  }

  Widget _segmentChip(String label, bool selected, VoidCallback onSelected) {
    return ChoiceChip(
      label: Center(child: Text(label, overflow: TextOverflow.ellipsis)),
      selected: selected,
      selectedColor: Pb.yellow,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(color: Pb.ink, fontWeight: selected ? FontWeight.w900 : FontWeight.w700),
      side: BorderSide(color: selected ? Pb.yellowDeep : Pb.ink.withOpacity(0.12)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (_) => onSelected(),
    );
  }

  Widget _renterTips() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Pb.ink.withOpacity(0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.route_outlined, color: Pb.yellowDeep),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Search an area, filter by fit and access, save good spots, then check the price breakdown before booking.',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Pb.ink),
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            onPressed: _dismissRenterTips,
            icon: const Icon(Icons.close, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _emptyState(I18n i, {bool map = false}) {
    final locationBlocked = locationStatus != LocationStatus.granted && locationStatus != LocationStatus.loading;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(map ? Icons.map_outlined : Icons.local_parking_outlined, size: 46, color: Pb.muted),
            const SizedBox(height: 12),
            Text(
              locationBlocked ? 'No nearby spots from this view' : 'No spots match these filters',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Pb.ink),
            ),
            const SizedBox(height: 8),
            Text(
              locationBlocked
                  ? _locationHelp(locationStatus)
                  : 'Try a wider distance, another price focus, or turn off Available now.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Pb.muted, fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.tune),
                  label: const Text('Adjust filters'),
                  onPressed: _showFilters,
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                  style: FilledButton.styleFrom(backgroundColor: Pb.ink, foregroundColor: Colors.white),
                  onPressed: () {
                    setState(() {
                      covered = null;
                      vehicleSize = 'any';
                      accessType = 'any';
                      priceMode = 'monthly';
                      verifiedOnly = false;
                      availableNow = false;
                      maxKm = 12;
                      maxHourly = 250;
                      maxDaily = 1500;
                      maxMonthly = 15000;
                    });
                    _load(visibleBounds: mapMode && _mapReady);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
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
        if (showRenterTips) _renterTips(),
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
                  const TextButton(onPressed: Geolocator.openAppSettings, child: Text('Settings')),
              ],
            ),
          ),
        if (loading) const Expanded(child: Center(child: CircularProgressIndicator(color: Pb.yellow))),
        if (!loading && err == null)
          Expanded(
            child: mapMode
                ? (_visibleSpots.isEmpty ? _emptyState(i, map: true) : _map())
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: _visibleSpots.isEmpty ? _emptyState(i) : SpotDeck(spots: _visibleSpots, onTap: (spot) => _selectSpot(spot)),
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
                onTap: () {
                  setState(() => savedOnly = !savedOnly);
                  if (savedOnly) _loadFavorites();
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: savedOnly ? Pb.yellow : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Icon(savedOnly ? Icons.bookmark : Icons.bookmark_border, color: Pb.ink),
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
          if (suggestions.isEmpty && searchController.text.trim().isEmpty && recentSearches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: recentSearches.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final term = recentSearches[index];
                    return ActionChip(
                      avatar: const Icon(Icons.history, size: 16),
                      label: Text(term),
                      onPressed: () {
                        searchController.text = term;
                        _fetchSuggestions(term);
                      },
                    );
                  },
                ),
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
    if (_zoom >= 16.5) return _visibleSpots.map((s) => [s]).toList();
    final cell = _zoom < 12 ? 0.04 : _zoom < 14 ? 0.018 : 0.006;
    final buckets = <String, List<Map<String, dynamic>>>{};
    for (final spot in _visibleSpots) {
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
