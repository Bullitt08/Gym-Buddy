import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_keys.dart';

class GooglePlacesService {
  // Google Maps API Key from secure config
  static String get _apiKey => ApiKeys.googleMapsApiKey;
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';

  // Nearby search for gyms and fitness centers
  Future<List<PlaceResult>> getNearbyGyms(double lat, double lng,
      {int radius = 5000}) async {
    final String url = '$_baseUrl/nearbysearch/json?'
        'location=$lat,$lng&'
        'radius=$radius&'
        'type=establishment&'
        'keyword=fitness|gym|spor|antrenman|workout|health+club|sports+center&'
        'key=$_apiKey';

    print('DEBUG: Places API URL: $url');

    try {
      final response = await http.get(Uri.parse(url));

      print('DEBUG: Places API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        print('DEBUG: Places API Response Status: ${data['status']}');
        print(
            'DEBUG: Places API Results Count: ${data['results']?.length ?? 0}');

        if (data['status'] == 'OK') {
          final List results = data['results'] ?? [];
          final gyms =
              results.map((place) => PlaceResult.fromJson(place)).toList();

          // Debug: Print first few gym names
          for (int i = 0; i < (gyms.length < 3 ? gyms.length : 3); i++) {
            print('DEBUG: Found gym: ${gyms[i].name} - ${gyms[i].vicinity}');
          }

          return gyms;
        } else {
          print(
              'DEBUG: Places API Error Details: ${data['error_message'] ?? 'No error message'}');
          throw Exception('Places API Error: ${data['status']}');
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG: Exception in getNearbyGyms: $e');
      throw Exception('Failed to fetch nearby gyms: $e');
    }
  }

  // Text search for specific gym names
  Future<List<PlaceResult>> searchGyms(
      String query, double lat, double lng) async {
    final String url = '$_baseUrl/textsearch/json?'
        'query=${Uri.encodeComponent(query)} gym fitness spor&'
        'location=$lat,$lng&'
        'radius=10000&'
        'type=gym&'
        'key=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final List results = data['results'] ?? [];
          return results.map((place) => PlaceResult.fromJson(place)).toList();
        } else {
          throw Exception('Places API Error: ${data['status']}');
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to search gyms: $e');
    }
  }

  // Get place details
  Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    final String url = '$_baseUrl/details/json?'
        'place_id=$placeId&'
        'fields=name,formatted_address,geometry,rating,opening_hours,formatted_phone_number&'
        'key=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['result'] != null) {
          return PlaceDetails.fromJson(data['result']);
        }
      }
      return null;
    } catch (e) {
      print('Error fetching place details: $e');
      return null;
    }
  }
}

class PlaceResult {
  final String placeId;
  final String name;
  final String? vicinity;
  final double lat;
  final double lng;
  final double? rating;
  final String? priceLevel;
  final bool isOpen;
  final List<String> types;

  PlaceResult({
    required this.placeId,
    required this.name,
    this.vicinity,
    required this.lat,
    required this.lng,
    this.rating,
    this.priceLevel,
    required this.isOpen,
    required this.types,
  });

  factory PlaceResult.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'];
    final location = geometry['location'];

    return PlaceResult(
      placeId: json['place_id'] ?? '',
      name: json['name'] ?? 'Unknown Place',
      vicinity: json['vicinity'],
      lat: (location['lat'] ?? 0.0).toDouble(),
      lng: (location['lng'] ?? 0.0).toDouble(),
      rating: json['rating']?.toDouble(),
      priceLevel: json['price_level']?.toString(),
      isOpen: json['opening_hours']?['open_now'] ?? false,
      types: List<String>.from(json['types'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'place_id': placeId,
      'name': name,
      'vicinity': vicinity,
      'lat': lat,
      'lng': lng,
      'rating': rating,
      'price_level': priceLevel,
      'is_open': isOpen,
      'types': types,
    };
  }
}

class PlaceDetails {
  final String name;
  final String formattedAddress;
  final double lat;
  final double lng;
  final double? rating;
  final String? phoneNumber;
  final bool? isOpen;
  final List<String>? weekdayText;

  PlaceDetails({
    required this.name,
    required this.formattedAddress,
    required this.lat,
    required this.lng,
    this.rating,
    this.phoneNumber,
    this.isOpen,
    this.weekdayText,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'];
    final location = geometry['location'];

    return PlaceDetails(
      name: json['name'] ?? 'Unknown Place',
      formattedAddress: json['formatted_address'] ?? '',
      lat: (location['lat'] ?? 0.0).toDouble(),
      lng: (location['lng'] ?? 0.0).toDouble(),
      rating: json['rating']?.toDouble(),
      phoneNumber: json['formatted_phone_number'],
      isOpen: json['opening_hours']?['open_now'],
      weekdayText: json['opening_hours']?['weekday_text'] != null
          ? List<String>.from(json['opening_hours']['weekday_text'])
          : null,
    );
  }
}
