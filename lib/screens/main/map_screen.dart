import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui' as ui;
import '../../providers/location_provider.dart';
import 'gym_profile_screen.dart' as gym_profile;
import '../../config/api_keys.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  double _currentZoom = 14.0;
  Marker? _userLocationMarker;
  List<Map<String, dynamic>> _nearbyGyms = [];
  Map<String, Marker> _gymMarkers = {}; // Store gym markers
  String? _lastSearchLocation; // Track last search location
  bool _showInfoCard = true;
  MapType _currentMapType = MapType.normal;
  bool _showMapTypeMenu = false;

  // Default location (Istanbul)
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(0, 0),
    zoom: 50.0,
  );

  // Google Places API Key from secure config
  static String get _placesApiKey => ApiKeys.googleMapsApiKey;

  @override
  void initState() {
    super.initState();
    print('DEBUG: MapScreen initState');

    // Get location with location provider and auto-center map
    Future.microtask(() async {
      print('DEBUG: Starting location request in initState');
      try {
        print('DEBUG: Calling getCurrentLocation...');
        await ref.read(locationProvider.notifier).getCurrentLocation();

        final locationState = ref.read(locationProvider);
        print(
            'DEBUG: Location state after request: ${locationState.currentPosition}');
        print('DEBUG: Location error: ${locationState.errorMessage}');
        print('DEBUG: Location loading: ${locationState.isLoading}');

        await Future.delayed(const Duration(milliseconds: 1000));
        _centerMapOnUserLocation();
      } catch (e) {
        print('DEBUG: Error in initState: $e');
      }
    });
  }

  void _centerMapOnUserLocation() {
    final locationState = ref.read(locationProvider);
    print(
        'DEBUG: _centerMapOnUserLocation called. Position: ${locationState.currentPosition}');
    print('DEBUG: Map controller ready: ${_mapController != null}');

    if (locationState.currentPosition != null && _mapController != null) {
      final userLatLng = LatLng(
        locationState.currentPosition!.latitude,
        locationState.currentPosition!.longitude,
      );

      print(
          'DEBUG: Centering map on user location: ${userLatLng.latitude}, ${userLatLng.longitude}');

      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: userLatLng,
            zoom: 16.0, // Optimal zoom level for gyms
            bearing: 0,
            tilt: 0,
          ),
        ),
      );
    } else {
      print(
          'DEBUG: Cannot center map - position: ${locationState.currentPosition}, controller: ${_mapController != null}');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to location state changes and auto-center
    final locationState = ref.watch(locationProvider);
    if (locationState.currentPosition != null) {
      // Center map when location is obtained for the first time
      if (_userLocationMarker == null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _centerMapOnUserLocation();
        });
      }

      // User marker removed
    }
  }

  void _goToCurrentLocation() async {
    print('DEBUG: _goToCurrentLocation called');

    // Start getting location
    await ref.read(locationProvider.notifier).getCurrentLocation();

    // Wait briefly and check again
    await Future.delayed(const Duration(milliseconds: 500));

    final locationState = ref.read(locationProvider);

    if (locationState.currentPosition != null && _mapController != null) {
      final userLatLng = LatLng(
        locationState.currentPosition!.latitude,
        locationState.currentPosition!.longitude,
      );

      print(
          'DEBUG: Moving camera to user location: ${userLatLng.latitude}, ${userLatLng.longitude}');

      // Animated transition to user location - closer zoom
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: userLatLng,
            zoom: 17.0, // Closer zoom for gyms to be visible
            bearing: 0,
            tilt: 0,
          ),
        ),
      );

      // Success message with SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location found! Nearby gyms should be visible.'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else if (locationState.errorMessage != null) {
      print('DEBUG: Location error: ${locationState.errorMessage}');

      // Show error SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(locationState.errorMessage!),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _goToCurrentLocation,
            ),
          ),
        );
      }
    }
  }

  // Kullanıcı marker'ı kaldırıldı - Google Maps native location kullanılıyor

  Future<BitmapDescriptor> _createGymIcon() async {
    try {
      // fitness_center ikonunu marker olarak kullan
      const iconData = Icons.fitness_center;
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      final size = 100.0;

      // Orange background circle
      final backgroundPaint = Paint()
        ..color = Colors.orange
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(size / 2, size / 2),
        size / 2,
        backgroundPaint,
      );

      // White border
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      canvas.drawCircle(
        Offset(size / 2, size / 2),
        size / 2 - 1.5,
        borderPaint,
      );

      // Draw fitness_center icon
      final textPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(iconData.codePoint),
          style: TextStyle(
            fontSize: size * 0.5,
            fontFamily: iconData.fontFamily,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          (size - textPainter.width) / 2,
          (size - textPainter.height) / 2,
        ),
      );

      final picture = pictureRecorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

      return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
    } catch (e) {
      print('DEBUG: Error creating fitness center icon: $e');
      // Fallback to orange marker
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
  }

  // Özel marker fonksiyonu kaldırıldı - basit renk marker kullanılıyor

  Future<void> _searchNearbyGyms(LatLng location) async {
    try {
      // Prevent searching at the same location (within 100m)
      String currentLocationKey =
          '${(location.latitude * 1000).round()}_${(location.longitude * 1000).round()}';
      if (_lastSearchLocation == currentLocationKey) {
        print('DEBUG: Skipping search - same location as before');
        return;
      }
      _lastSearchLocation = currentLocationKey;

      print(
          'DEBUG: Searching gyms near ${location.latitude}, ${location.longitude}');

      List<Map<String, dynamic>> allGyms = [];
      String? nextPageToken;
      int pageCount = 0;
      const int maxPages = 10;

      do {
        // Google Places API - Nearby Search with pagination
        String url =
            'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
            '?location=${location.latitude},${location.longitude}'
            '&radius=5000' // 5km radius
            '&type=gym'
            '&keyword=fitness|gym|spor|antrenman'
            '&key=$_placesApiKey';

        if (nextPageToken != null) {
          url += '&pagetoken=$nextPageToken';
          // Pagination için 2 saniye bekle (Google API requirement)
          await Future.delayed(const Duration(seconds: 2));
        }

        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          if (data['status'] == 'OK') {
            final results =
                List<Map<String, dynamic>>.from(data['results'] ?? []);
            allGyms.addAll(results);
            nextPageToken = data['next_page_token'];
            pageCount++;

            print(
                'DEBUG: Page $pageCount - Found ${results.length} gyms (Total: ${allGyms.length})');
          } else if (data['status'] == 'ZERO_RESULTS') {
            print('DEBUG: No more gyms found');
            break;
          } else {
            print('DEBUG: Places API error: ${data['status']}');
            break;
          }
        } else {
          print('DEBUG: HTTP error: ${response.statusCode}');
          break;
        }
      } while (nextPageToken != null && pageCount < maxPages);

      // Add new gyms to existing gym list (prevent duplicates)
      for (var gym in allGyms) {
        final placeId = gym['place_id'];
        if (placeId != null &&
            !_nearbyGyms
                .any((existingGym) => existingGym['place_id'] == placeId)) {
          _nearbyGyms.add(gym);
        }
      }

      print('DEBUG: Total unique gyms found: ${_nearbyGyms.length}');

      // Add gym markers
      _addGymMarkers();
    } catch (e) {
      print('DEBUG: Error searching gyms: $e');
    }
  }

  Future<void> _addGymMarkers() async {
    try {
      // Create custom gym icon (create once and reuse)
      final BitmapDescriptor gymIcon = await _createGymIcon();

      // Add new markers (keep existing ones)
      for (int i = 0; i < _nearbyGyms.length; i++) {
        final gym = _nearbyGyms[i];
        final placeId = gym['place_id'];

        // Skip if marker already exists for this gym
        if (placeId != null && _gymMarkers.containsKey(placeId)) {
          continue;
        }

        final geometry = gym['geometry'];
        if (geometry == null || geometry['location'] == null) {
          print('DEBUG: Skipping gym ${gym['name']} - no location data');
          continue;
        }

        final location = geometry['location'];

        try {
          final marker = Marker(
            markerId: MarkerId('gym_${placeId ?? i}'),
            position: LatLng(
              location['lat'].toDouble(),
              location['lng'].toDouble(),
            ),
            icon: gymIcon,
            infoWindow: InfoWindow(
              title: gym['name'] ?? 'Gym',
              snippet: '🏋️ ${gym['rating'] ?? 'N/A'} ⭐ • Tap for more info',
              onTap: () => _navigateToGymProfile(gym),
            ),
          );

          if (placeId != null) {
            _gymMarkers[placeId] = marker;
          }
          print('DEBUG: Added marker for gym: ${gym['name']}');
        } catch (e) {
          print('DEBUG: Error creating marker for gym ${gym['name']}: $e');
        }
      }

      // Add all gym markers to map
      setState(() {
        _markers = Set<Marker>.from(_gymMarkers.values);
      });

      print('DEBUG: Total markers on map: ${_markers.length}');
    } catch (e) {
      print('DEBUG: Error in _addGymMarkers: $e');
    }
  }

  void _navigateToGymProfile(Map<String, dynamic> gym) {
    final geometry = gym['geometry'];
    final location = geometry?['location'];

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => gym_profile.GymProfileScreen(
          gymId: gym['name'] ?? 'Unknown Gym',
          gymName: gym['name'],
          placeId: gym['place_id'],
          lat: location?['lat']?.toDouble(),
          lng: location?['lng']?.toDouble(),
        ),
      ),
    );
  }

  Future<void> _searchGymsAroundCurrentView() async {
    if (_mapController == null) return;

    try {
      // Check zoom level - search gyms only after certain zoom level
      final currentZoom = await _mapController!.getZoomLevel();
      const double minZoomForGyms =
          13.0; // Search for gyms even at lower zoom level

      print(
          'DEBUG: Current zoom level: $currentZoom, Min required: $minZoomForGyms');

      if (currentZoom < minZoomForGyms) {
        print('DEBUG: Zoom level too low - clearing gym markers');
        // Clear markers if zoom level is too low
        setState(() {
          _markers.clear();
        });
        return;
      }

      // Get current camera position
      final LatLngBounds bounds = await _mapController!.getVisibleRegion();
      final LatLng center = LatLng(
        (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
        (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
      );

      print(
          'DEBUG: Searching gyms around camera position: ${center.latitude}, ${center.longitude}');

      // If zoom level is sufficient, restore markers or search for new gyms
      if (_markers.isEmpty && _gymMarkers.isNotEmpty) {
        // Restore existing gym markers
        setState(() {
          _markers = Set<Marker>.from(_gymMarkers.values);
        });
        print('DEBUG: Restored ${_markers.length} existing gym markers');
      } else {
        // Search for new gyms
        await _searchNearbyGyms(center);
      }
    } catch (e) {
      print('DEBUG: Error getting camera position: $e');
    }
  }

  Future<void> _zoomIn() async {
    if (_mapController != null) {
      _currentZoom = await _mapController!.getZoomLevel();
      if (_currentZoom < 21) {
        _mapController!.animateCamera(
          CameraUpdate.zoomTo(_currentZoom + 1),
        );
      }
    }
  }

  Future<void> _zoomOut() async {
    if (_mapController != null) {
      _currentZoom = await _mapController!.getZoomLevel();
      if (_currentZoom > 1) {
        _mapController!.animateCamera(
          CameraUpdate.zoomTo(_currentZoom - 1),
        );
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _loadMarkers();
    // Center location after map loads
    Future.delayed(const Duration(milliseconds: 1000), () {
      _centerMapOnUserLocation();
    });
  }

  void _loadMarkers() {
    // Gym markers are added in _addGymMarkers() function
    // This function is called when map loads
  }

  void _toggleInfoCard() {
    setState(() {
      _showInfoCard = !_showInfoCard;
    });
  }

  void _toggleMapTypeMenu() {
    setState(() {
      _showMapTypeMenu = !_showMapTypeMenu;
    });
  }

  void _changeMapType(MapType mapType) {
    setState(() {
      _currentMapType = mapType;
      _showMapTypeMenu = false;
    });
  }

  IconData _getMapTypeIcon(MapType mapType) {
    switch (mapType) {
      case MapType.normal:
        return Icons.map;
      case MapType.satellite:
        return Icons.satellite_alt;
      case MapType.hybrid:
        return Icons.layers;
      case MapType.terrain:
        return Icons.terrain;
      default:
        return Icons.map;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);

    return Scaffold(
      body: GestureDetector(
        onTap: () {
          if (_showMapTypeMenu) {
            setState(() {
              _showMapTypeMenu = false;
            });
          }
        },
        child: Stack(
          children: [
            // Google Maps
            GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                _onMapCreated(controller);
                print('DEBUG: Google Maps created successfully');
              },
              initialCameraPosition: _initialPosition,
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              mapType: _currentMapType,
              zoomControlsEnabled: false,
              compassEnabled: false, // Compass hidden - cleaner appearance
              rotateGesturesEnabled: false, // Rotation disableded
              scrollGesturesEnabled: true,
              tiltGesturesEnabled: false, // Tilt disabled
              zoomGesturesEnabled: true,
              // POI (Points of Interest) - gym focused only
              buildingsEnabled: false, // Buildings hidden - only POIs visible
              // Hide traffic information
              trafficEnabled: false,
              // Turn off indoor maps - focus on outdoor gyms
              indoorViewEnabled: false,
              // Turn off lite mode (required for POIs)
              liteModeEnabled: false,
              // For minimum clutter
              mapToolbarEnabled: false,
              // Add padding to increase marker visibility
              padding: const EdgeInsets.only(top: 100, bottom: 100),
              onCameraMove: (CameraPosition position) {
                _currentZoom = position.zoom;
              },
              onCameraIdle: () {
                // Search gyms when camera movement stops
                _searchGymsAroundCurrentView();
              },
            ),

            // Location error overlay
            if (locationState.errorMessage != null)
              Positioned(
                top: 100,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          locationState.errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(locationProvider.notifier).clearError();
                        },
                        child: const Text('Dismiss'),
                      ),
                    ],
                  ),
                ),
              ),

            // Left side controls
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: FloatingActionButton.small(
                        heroTag: "map_location_fab",
                        onPressed: locationState.isLoading
                            ? null
                            : _goToCurrentLocation,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        child: locationState.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.orange),
                                ),
                              )
                            : const Icon(Icons.my_location,
                                color: Colors.orange),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Zoom controls below location button
                    Container(
                      width: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Zoom In
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _zoomIn,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(25),
                                topRight: Radius.circular(25),
                              ),
                              child: Container(
                                width: 50,
                                height: 50,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          // Divider
                          Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            color: Colors.grey.shade300,
                          ),
                          // Zoom Out
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _zoomOut,
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(25),
                                bottomRight: Radius.circular(25),
                              ),
                              child: Container(
                                width: 50,
                                height: 50,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.remove,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Map type button
                    Container(
                      width: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _toggleMapTypeMenu,
                          borderRadius: BorderRadius.circular(25),
                          child: Container(
                            width: 50,
                            height: 50,
                            alignment: Alignment.center,
                            child: Icon(
                              _getMapTypeIcon(_currentMapType),
                              color: Colors.orange,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Map type menu
            if (_showMapTypeMenu)
              Positioned(
                top: 200,
                left: 82,
                child: Container(
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMapTypeOption(MapType.normal, 'Normal', Icons.map),
                      const Divider(height: 1),
                      _buildMapTypeOption(
                          MapType.satellite, 'Satellite', Icons.satellite_alt),
                      const Divider(height: 1),
                      _buildMapTypeOption(
                          MapType.hybrid, 'Hybrid', Icons.layers),
                      const Divider(height: 1),
                      _buildMapTypeOption(
                          MapType.terrain, 'Terrain', Icons.terrain),
                    ],
                  ),
                ),
              ),

            // Info card toggle button
            Positioned(
              bottom: _showInfoCard ? 120 : 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: FloatingActionButton.small(
                  heroTag: "info_toggle_fab",
                  onPressed: _toggleInfoCard,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  child: Icon(
                    _showInfoCard
                        ? Icons.keyboard_arrow_down
                        : Icons.info_outline,
                    color: Colors.orange,
                  ),
                ),
              ),
            ),

            // Bottom info card (conditionally shown)
            if (_showInfoCard)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'My Location',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 16),
                          const Icon(
                            Icons.fitness_center,
                            color: Colors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Gyms',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        locationState.currentPosition != null
                            ? 'Found ${_markers.length} gyms nearby. Move the map to discover more!'
                            : 'Tap the location button to find your position.',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapTypeOption(MapType mapType, String label, IconData icon) {
    final isSelected = _currentMapType == mapType;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _changeMapType(mapType),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.orange : Colors.grey.shade600,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.orange : Colors.grey.shade700,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check,
                  color: Colors.orange,
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
