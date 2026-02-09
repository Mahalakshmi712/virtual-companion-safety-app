import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

// ============================================================================
// MAIN ENTRY POINT
// ============================================================================
void main() {
  runApp(const VirtualCompanionApp());
}

// ============================================================================
// ROOT APP WIDGET
// ============================================================================
class VirtualCompanionApp extends StatelessWidget {
  const VirtualCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Virtual Companion',
      theme: ThemeData(
        primarySwatch: Colors.red,
        useMaterial3: true,
      ),
      home: const SafetyTrackerScreen(),
      debugShowCheckedModeBanner: false, // Remove debug banner for demo
    );
  }
}

// ============================================================================
// MAIN SAFETY TRACKER SCREEN (The Core Logic Lives Here)
// ============================================================================
class SafetyTrackerScreen extends StatefulWidget {
  const SafetyTrackerScreen({super.key});

  @override
  State<SafetyTrackerScreen> createState() => _SafetyTrackerScreenState();
}

class _SafetyTrackerScreenState extends State<SafetyTrackerScreen> {
  // ---------------------------------------------------------------------------
  // TELEGRAM BOT CONFIGURATION (Your credentials)
  // ---------------------------------------------------------------------------
  final String botToken = "8543569631:AAGXC2bGlxd_4DxYePCZsfm5axrP7aM3GyI";
  final String chatId = "8368156725";

  // ---------------------------------------------------------------------------
  // STATE VARIABLES
  // ---------------------------------------------------------------------------
  
  // Current GPS position of the user
  Position? currentPosition;
  
  // Position from 10 seconds ago (used to calculate if user moved)
  Position? positionTenSecondsAgo;
  
  // Is the "Start Walk" feature currently active?
  bool isTracking = false;
  
  // Are we currently in "Warning State" (countdown before sending alert)?
  bool isWarningActive = false;
  
  // Countdown timer value (10 seconds countdown)
  int warningCountdown = 10;
  
  // For controlling the map camera position
  final MapController mapController = MapController();
  
  // Timer for GPS tracking every 5 seconds
  Timer? trackingTimer;
  
  // Timer for the 10-second warning countdown
  Timer? warningTimer;

  // ---------------------------------------------------------------------------
  // LIFECYCLE: When the app starts, request location permissions
  // ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  // ---------------------------------------------------------------------------
  // LIFECYCLE: When the app closes, cancel all timers to prevent memory leaks
  // ---------------------------------------------------------------------------
  @override
  void dispose() {
    trackingTimer?.cancel();
    warningTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // FUNCTION 1: Request GPS Permission from the User
  // ---------------------------------------------------------------------------
  Future<void> _requestLocationPermission() async {
    // Check if location services are enabled on the device
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Please enable GPS location services');
      return;
    }

    // Check current permission status
    LocationPermission permission = await Geolocator.checkPermission();
    
    // If denied, request permission
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Location permission denied');
        return;
      }
    }

    // If permanently denied, show message
    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Location permission permanently denied. Enable in settings.');
      return;
    }

    // Permission granted! Get initial location
    _getCurrentLocation();
  }

  // ---------------------------------------------------------------------------
  // FUNCTION 2: Get Current GPS Location (One-Time)
  // ---------------------------------------------------------------------------
  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high, // High accuracy GPS
      );
      
      setState(() {
        currentPosition = position;
      });

      // Move map camera to user's location
      if (currentPosition != null) {
        mapController.move(
          LatLng(currentPosition!.latitude, currentPosition!.longitude),
          15.0, // Zoom level
        );
      }
    } catch (e) {
      _showSnackBar('Error getting location: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // FUNCTION 3: Start Walk - Begin GPS Tracking Every 5 Seconds
  // ---------------------------------------------------------------------------
  void _startTracking() {
    setState(() {
      isTracking = true;
      positionTenSecondsAgo = null; // Reset previous position
    });

    _showSnackBar('Walk started! Monitoring your movement...');

    // Record GPS every 5 seconds
    trackingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await _trackLocation();
    });
  }

  // ---------------------------------------------------------------------------
  // FUNCTION 4: Stop Walk - Stop All Tracking
  // ---------------------------------------------------------------------------
  void _stopTracking() {
    trackingTimer?.cancel();
    warningTimer?.cancel();
    
    setState(() {
      isTracking = false;
      isWarningActive = false;
      warningCountdown = 10;
      positionTenSecondsAgo = null;
    });

    _showSnackBar('Walk stopped');
  }

  // ---------------------------------------------------------------------------
  // FUNCTION 5: Track Location (Called Every 5 Seconds)
  // This is the CORE LOGIC of the "Dead Man's Switch"
  // ---------------------------------------------------------------------------
  Future<void> _trackLocation() async {
    try {
      // Get current GPS position
      Position newPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Update map to show current location
      setState(() {
        currentPosition = newPosition;
      });
      
      mapController.move(
        LatLng(newPosition.latitude, newPosition.longitude),
        15.0,
      );

      // CRITICAL LOGIC: Check if user has moved in the last 10 seconds
      if (positionTenSecondsAgo != null) {
        // Calculate distance between current position and position 10 seconds ago
        double distanceInMeters = Geolocator.distanceBetween(
          positionTenSecondsAgo!.latitude,
          positionTenSecondsAgo!.longitude,
          newPosition.latitude,
          newPosition.longitude,
        );

        print('Distance moved in last 10 seconds: ${distanceInMeters.toStringAsFixed(2)} meters');

        // DANGER DETECTED: User moved less than 5 meters in 10 seconds
        if (distanceInMeters < 5.0 && !isWarningActive) {
          _triggerWarning();
        } else if (distanceInMeters >= 5.0 && isWarningActive) {
          // User started moving again, cancel warning
          _cancelWarning();
        }
      }

      // Update the "10 seconds ago" position for next comparison
      // We do this after a delay to ensure we're always comparing with data from 10 seconds ago
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            positionTenSecondsAgo = newPosition;
          });
        }
      });

    } catch (e) {
      print('Error tracking location: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // FUNCTION 6: Trigger Warning - Start 10-Second Countdown
  // ---------------------------------------------------------------------------
  void _triggerWarning() {
    setState(() {
      isWarningActive = true;
      warningCountdown = 10;
    });

    _showSnackBar('⚠️ WARNING: No movement detected!');

    // Start countdown timer (1 second intervals)
    warningTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        warningCountdown--;
      });

      // Countdown reached zero - SEND DISTRESS SIGNAL
      if (warningCountdown <= 0) {
        timer.cancel();
        _sendDistressSignal();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // FUNCTION 7: Cancel Warning - User Moved or Pressed Cancel
  // ---------------------------------------------------------------------------
  void _cancelWarning() {
    warningTimer?.cancel();
    
    setState(() {
      isWarningActive = false;
      warningCountdown = 10;
    });

    _showSnackBar('Warning cancelled - movement detected');
  }

  // ---------------------------------------------------------------------------
  // FUNCTION 8: Send Distress Signal to Telegram
  // This sends your GPS coordinates to your Telegram chat
  // ---------------------------------------------------------------------------
  Future<void> _sendDistressSignal() async {
    if (currentPosition == null) {
      _showSnackBar('Cannot send alert: Location unavailable');
      return;
    }

    // Format the message with GPS coordinates and Google Maps link
    String message = '''
🚨 DISTRESS SIGNAL 🚨

Location: ${currentPosition!.latitude}, ${currentPosition!.longitude}

Google Maps: https://www.google.com/maps?q=${currentPosition!.latitude},${currentPosition!.longitude}

Timestamp: ${DateTime.now()}
    ''';

    // Build the Telegram Bot API URL
    String url = 'https://api.telegram.org/bot$botToken/sendMessage'
        '?chat_id=$chatId'
        '&text=${Uri.encodeComponent(message)}';

    try {
      // Send HTTP GET request to Telegram
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        _showSnackBar('✅ Distress signal sent to Telegram!');
        print('Telegram response: ${response.body}');
      } else {
        _showSnackBar('❌ Failed to send alert');
        print('Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      _showSnackBar('Error sending alert: $e');
      print('Exception: $e');
    }

    // Reset warning state after sending
    setState(() {
      isWarningActive = false;
      warningCountdown = 10;
    });
  }

  // ---------------------------------------------------------------------------
  // HELPER FUNCTION: Show Messages to User
  // ---------------------------------------------------------------------------
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  // ---------------------------------------------------------------------------
  // UI BUILD METHOD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Virtual Companion Safety'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // =====================================================================
          // MAP DISPLAY (Using OpenStreetMap via flutter_map)
          // =====================================================================
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              // Default center (will update when GPS is available)
              initialCenter: currentPosition != null
                  ? LatLng(currentPosition!.latitude, currentPosition!.longitude)
                  : const LatLng(0, 0),
              initialZoom: 15.0,
            ),
            children: [
              // OpenStreetMap tile layer (free alternative to Google Maps)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.virtual_companion',
              ),
              
              // User location marker
              if (currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(
                        currentPosition!.latitude,
                        currentPosition!.longitude,
                      ),
                      width: 80,
                      height: 80,
                      child: const Icon(
                        Icons.person_pin_circle,
                        color: Colors.red,
                        size: 50,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // =====================================================================
          // CONTROL PANEL (Bottom overlay)
          // =====================================================================
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Status indicator
                  if (isTracking)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isWarningActive ? Colors.red : Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isWarningActive
                            ? '⚠️ WARNING: No Movement!'
                            : '✓ Tracking Active',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Warning countdown display
                  if (isWarningActive)
                    Column(
                      children: [
                        Text(
                          'Sending alert in...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$warningCountdown',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _cancelWarning,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                          child: const Text(
                            'CANCEL ALERT',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),

                  // Main control button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isTracking ? _stopTracking : _startTracking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isTracking ? Colors.grey : Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isTracking ? 'STOP WALK' : 'START WALK',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // Current location display
                  if (currentPosition != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Location: ${currentPosition!.latitude.toStringAsFixed(6)}, '
                        '${currentPosition!.longitude.toStringAsFixed(6)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}