import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';

class EWasteMapScreen extends StatefulWidget {
  final List<dynamic> locations;

  const EWasteMapScreen({Key? key, required this.locations}) : super(key: key);

  @override
  State<EWasteMapScreen> createState() => _EWasteMapScreenState();
}

class _EWasteMapScreenState extends State<EWasteMapScreen> {
  LatLng? _userLocation;
  Map<String, dynamic>? _nearestLocation;
  MapController _mapController = MapController();
  List<Map<String, dynamic>> _sortedLocations = [];

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _sortedLocations = _sortLocationsByDistance(position.latitude, position.longitude);
        _nearestLocation = _sortedLocations.first;
      });
    } catch (e) {
      print('Error getting user location: $e');
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Radius of Earth in kilometers
    double dLat = (lat2 - lat1) * pi / 180;
    double dLon = (lon2 - lon1) * pi / 180;

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
            sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  List<Map<String, dynamic>> _sortLocationsByDistance(double userLat, double userLon) {
    List<Map<String, dynamic>> locations = List.from(widget.locations);
    locations.sort((a, b) {
      double distanceA = _calculateDistance(
        userLat,
        userLon,
        a['latitude'],
        a['longitude'],
      );
      double distanceB = _calculateDistance(
        userLat,
        userLon,
        b['latitude'],
        b['longitude'],
      );
      return distanceA.compareTo(distanceB);
    });

    return locations;
  }

  String _formatDistance(double distance) {
    if (distance < 1) {
      // Show in meters if less than 1km
      return '${(distance * 1000).toStringAsFixed(0)} m';
    } else {
      return '${distance.toStringAsFixed(1)} km';
    }
  }

  void _showLocationDetails(BuildContext context, Map<String, dynamic> location) {
    double distance = _calculateDistance(
      _userLocation!.latitude,
      _userLocation!.longitude,
      location['latitude'],
      location['longitude'],
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(location['name']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Distance: ${_formatDistance(distance)}'),
            const SizedBox(height: 8),
            Text('Address: ${location['address']}'),
            const SizedBox(height: 8),
            Text('Phone: ${location['phone']}'),
            const SizedBox(height: 8),
            Text('Hours: ${location['hours']}'),
            const SizedBox(height: 8),
            Text('Accepted Materials: ${location['accepted_materials'].join(', ')}'),
            const SizedBox(height: 8),
            Text('Notes: ${location['notes']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              final url = location['website'];
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url));
              }
            },
            child: const Text('Visit Website'),
          ),
        ],
      ),
    );
  }

  void _animateToLocation(LatLng location) {
    _mapController.move(location, 15.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E-Waste Disposal Locations'),
      ),
      body: _userLocation == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    center: _userLocation,
                    zoom: 13.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: ['a', 'b', 'c'],
                    ),
                    MarkerLayer(
                      markers: [
                        // User location marker
                        Marker(
                          point: _userLocation!,
                          builder: (ctx) => const Icon(
                            Icons.person_pin_circle,
                            color: Colors.blue,
                            size: 40,
                          ),
                        ),
                        // E-waste facility markers
                        ...widget.locations.map((location) {
                          bool isNearest = location == _nearestLocation;
                          return Marker(
                            point: LatLng(location['latitude'], location['longitude']),
                            builder: (ctx) => GestureDetector(
                              onTap: () => _showLocationDetails(context, location),
                              child: Icon(
                                Icons.location_on,
                                color: isNearest ? Colors.green : Colors.red,
                                size: isNearest ? 40 : 30,
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ],
                ),
                DraggableScrollableSheet(
                  initialChildSize: 0.2,
                  minChildSize: 0.2,
                  maxChildSize: 0.8,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Oval-like icon to indicate expandability
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Container(
                              width: 40,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.grey[400],
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              controller: scrollController,
                              itemCount: _sortedLocations.length,
                              itemBuilder: (context, index) {
                                final location = _sortedLocations[index];
                                double distance = _calculateDistance(
                                  _userLocation!.latitude,
                                  _userLocation!.longitude,
                                  location['latitude'],
                                  location['longitude'],
                                );
                                return ListTile(
                                  leading: Icon(Icons.location_on,
                                      color: location == _nearestLocation ? Colors.green : Colors.red),
                                  title: Text(location['name']),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(location['address']),
                                      Text(
                                        _formatDistance(distance),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    _animateToLocation(LatLng(
                                      location['latitude'],
                                      location['longitude'],
                                    ));
                                    _showLocationDetails(context, location);
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Screen'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            try {
              final jsonString = await rootBundle.loadString('assets/e_waste_locations.json');
              final jsonData = json.decode(jsonString);
              final locations = jsonData['e_waste_locations'] as List<dynamic>;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EWasteMapScreen(locations: locations),
                ),
              );
            } catch (e) {
              print('Error loading e-waste locations: $e');
            }
          },
          child: const Text('View E-Waste Locations'),
        ),
      ),
    );
  }
}