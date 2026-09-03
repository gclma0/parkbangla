import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class LocationResult {
  const LocationResult({
    this.point,
    this.accuracyM,
    this.status = LocationStatus.unrequested,
    this.message,
  });

  final LatLng? point;
  final double? accuracyM;
  final LocationStatus status;
  final String? message;

  bool get hasPoint => point != null;
}

enum LocationStatus {
  unrequested,
  loading,
  granted,
  denied,
  permanentlyDenied,
  serviceDisabled,
  unavailable,
  timeout,
}

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.title,
    required this.subtitle,
    required this.point,
    required this.zoom,
    this.type = 'place',
    this.spotId,
    this.parkingCount,
    this.distanceKm,
  });

  final String title;
  final String subtitle;
  final LatLng point;
  final double zoom;
  final String type;
  final String? spotId;
  final int? parkingCount;
  final double? distanceKm;

  factory PlaceSuggestion.fromParkingJson(Map<String, dynamic> json) {
    return PlaceSuggestion(
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      point: LatLng((json['lat'] as num).toDouble(), (json['lng'] as num).toDouble()),
      zoom: (json['zoom'] as num?)?.toDouble() ?? 15,
      type: json['type']?.toString() ?? 'parking_area',
      spotId: json['spotId']?.toString(),
      parkingCount: (json['count'] as num?)?.toInt(),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
    );
  }

  factory PlaceSuggestion.fromNominatimJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? json['class']?.toString() ?? 'place';
    final display = json['display_name']?.toString() ?? '';
    final name = json['name']?.toString().trim();
    final title = name?.isNotEmpty == true ? name! : display.split(',').first.trim();
    final lat = double.parse(json['lat'].toString());
    final lon = double.parse(json['lon'].toString());
    return PlaceSuggestion(
      title: title,
      subtitle: display,
      point: LatLng(lat, lon),
      zoom: _zoomForOsmType(type),
      type: 'place',
    );
  }
}

Future<LocationResult> getCurrentLocation({Duration timeout = const Duration(seconds: 10)}) async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return const LocationResult(
      status: LocationStatus.serviceDisabled,
      message: 'Location services are disabled.',
    );
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.denied) {
    return const LocationResult(
      status: LocationStatus.denied,
      message: 'Location access helps find nearby parking.',
    );
  }

  if (permission == LocationPermission.deniedForever) {
    return const LocationResult(
      status: LocationStatus.permanentlyDenied,
      message: 'Location access is disabled in app settings.',
    );
  }

  try {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
      timeLimit: timeout,
    );
    return LocationResult(
      status: LocationStatus.granted,
      point: LatLng(position.latitude, position.longitude),
      accuracyM: position.accuracy,
    );
  } on TimeoutException {
    return const LocationResult(
      status: LocationStatus.timeout,
      message: 'Location request timed out.',
    );
  } catch (_) {
    return const LocationResult(
      status: LocationStatus.unavailable,
      message: 'Current location is temporarily unavailable.',
    );
  }
}

Future<List<PlaceSuggestion>> searchOsmPlaces(String query) async {
  final term = query.trim();
  if (term.length < 2) return [];

  final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
    'q': term,
    'format': 'jsonv2',
    'addressdetails': '1',
    'limit': '8',
    'countrycodes': 'bd',
  });
  final response = await http.get(uri, headers: const {
    'User-Agent': 'ParkBangla mobile location search',
  }).timeout(const Duration(seconds: 8));

  if (response.statusCode >= 400) return [];
  final decoded = jsonDecode(response.body);
  if (decoded is! List) return [];
  return decoded
      .whereType<Map>()
      .map((e) => PlaceSuggestion.fromNominatimJson(Map<String, dynamic>.from(e)))
      .toList();
}

double _zoomForOsmType(String type) {
  switch (type) {
    case 'city':
    case 'administrative':
      return 13;
    case 'suburb':
    case 'neighbourhood':
      return 15;
    case 'road':
    case 'residential':
    case 'service':
      return 17;
    case 'house':
    case 'building':
      return 18;
    default:
      return 16;
  }
}
