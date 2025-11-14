import 'package:flutter/material.dart';
import '../config/api_keys.dart';

class Gym {
  final String id;
  final String name;
  final String? address;
  final double? rating;
  final String? phoneNumber;
  final String? website;
  final Map<String, dynamic>? location; // {lat: double, lng: double}
  final List<String>? photos;
  final String? description;
  final List<String>? amenities;
  final Map<String, String>? openingHours; // {monday: "06:00-22:00", ...}
  final int? priceLevel; // 1-4 scale from Google Places
  final String? placeId; // Google Places ID
  final bool? isOpen;

  const Gym({
    required this.id,
    required this.name,
    this.address,
    this.rating,
    this.phoneNumber,
    this.website,
    this.location,
    this.photos,
    this.description,
    this.amenities,
    this.openingHours,
    this.priceLevel,
    this.placeId,
    this.isOpen,
  });

  factory Gym.fromGooglePlaces(Map<String, dynamic> data) {
    final geometry = data['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;

    return Gym(
      id: data['place_id'] ?? '',
      name: data['name'] ?? 'Unknown Gym',
      address: data['formatted_address'] ?? data['vicinity'],
      rating: (data['rating'] as num?)?.toDouble(),
      phoneNumber: data['formatted_phone_number'],
      website: data['website'],
      location: location != null
          ? {
              'lat': (location['lat'] as num).toDouble(),
              'lng': (location['lng'] as num).toDouble(),
            }
          : null,
      photos: (data['photos'] as List?)
          ?.map((photo) => _buildPhotoUrl(photo['photo_reference']))
          .toList(),
      description: data['editorial_summary']?['overview'],
      amenities: [], // Can be extracted from types or reviews
      openingHours: _parseOpeningHours(data['opening_hours']),
      priceLevel: data['price_level'] as int?,
      placeId: data['place_id'],
      isOpen: data['opening_hours']?['open_now'] as bool?,
    );
  }

  static String _buildPhotoUrl(String? photoReference) {
    if (photoReference == null) return '';
    final apiKey = ApiKeys.googleMapsApiKey;
    return 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=$photoReference&key=$apiKey';
  }

  static Map<String, String>? _parseOpeningHours(
      Map<String, dynamic>? openingHours) {
    if (openingHours == null) return null;

    final weekdayText = openingHours['weekday_text'] as List?;
    if (weekdayText == null) return null;

    Map<String, String> hours = {};
    for (String dayText in weekdayText) {
      final parts = dayText.split(': ');
      if (parts.length == 2) {
        hours[parts[0].toLowerCase()] = parts[1];
      }
    }
    return hours;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'rating': rating,
      'phoneNumber': phoneNumber,
      'website': website,
      'location': location,
      'photos': photos,
      'description': description,
      'amenities': amenities,
      'openingHours': openingHours,
      'priceLevel': priceLevel,
      'placeId': placeId,
      'isOpen': isOpen,
    };
  }

  factory Gym.fromJson(Map<String, dynamic> json) {
    return Gym(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'],
      rating: (json['rating'] as num?)?.toDouble(),
      phoneNumber: json['phoneNumber'],
      website: json['website'],
      location: json['location'] as Map<String, dynamic>?,
      photos: (json['photos'] as List?)?.cast<String>(),
      description: json['description'],
      amenities: (json['amenities'] as List?)?.cast<String>(),
      openingHours: (json['openingHours'] as Map?)?.cast<String, String>(),
      priceLevel: json['priceLevel'] as int?,
      placeId: json['placeId'],
      isOpen: json['isOpen'] as bool?,
    );
  }

  String get displayRating {
    if (rating == null) return 'No rating';
    return '${rating!.toStringAsFixed(1)} ⭐';
  }

  String get displayPriceLevel {
    if (priceLevel == null) return 'Price not available';
    return '\$' * priceLevel!;
  }

  String get displayStatus {
    if (isOpen == null) return 'Hours not available';
    return isOpen! ? 'Open now' : 'Closed';
  }

  Color get statusColor {
    if (isOpen == null) return Colors.grey;
    return isOpen! ? Colors.green : Colors.red;
  }
}
