import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Thin wrapper around the geolocator plugin: makes sure location services are
/// on, checks/requests permission, and returns the device's current position.
///
/// Deliberately returns null instead of throwing for every "can't get a real
/// location" case (services off, permission denied/denied forever, or no GPS
/// fix within the time limit - e.g. an emulator with no location set) so
/// callers can just fall back to a default location instead of hanging
/// forever or having to catch a pile of exception types.
class DeviceLocationService {
  const DeviceLocationService();

  /// How long to wait for a fresh GPS fix before giving up and returning null.
  /// Without this, an emulator/device with no location fix available leaves
  /// Geolocator.getCurrentPosition() waiting indefinitely.
  static const _timeout = Duration(seconds: 8);

  // NOTE: previously tried forcing geolocator_android's legacy LocationManager
  // path here (AndroidSettings(forceLocationManager: true)) to work around
  // emulators not feeding mock locations into the fused location provider.
  // On a 16KB-page-size emulator image ("gphone16k") that path native-crashed
  // instead (crash_dump64 "failed to attach to thread"), so it's reverted -
  // that emulator image is a known source of native-plugin crashes independent
  // of this bug. Stick to the default (fused) provider here.

  /// Returns the device's current position, or null if location services are
  /// off, permission wasn't granted, or no fix arrived within [_timeout].
  ///
  /// debugPrint calls below only show up in debug builds (e.g. `flutter run`
  /// console) - they're there so a "why is this returning null" question can
  /// be answered from the log instead of guessing.
  Future<Position?> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    debugPrint('[DeviceLocationService] serviceEnabled=$serviceEnabled');
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    debugPrint('[DeviceLocationService] initial permission=$permission');
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      debugPrint('[DeviceLocationService] permission after request=$permission');
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    // Ask for a FRESH fix first. This is what actually reflects whatever
    // location the device/emulator is set to right now - getLastKnownPosition
    // (tried below only as a fallback) can return a stale cached value from
    // before the current location was set, which is misleading rather than
    // helpful as a "fast path".
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: _timeout),
      ).timeout(_timeout); // belt-and-braces in case timeLimit isn't honored on this platform
      debugPrint('[DeviceLocationService] getCurrentPosition succeeded: $position');
      return position;
    } catch (e) {
      // Timeout, or a transient platform error - fall through to the cached fallback below.
      debugPrint('[DeviceLocationService] getCurrentPosition failed: $e');
    }

    // Last resort: a cached position is better than nothing, but it may be
    // old/stale, so it's only used when a fresh fix couldn't be obtained.
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      debugPrint('[DeviceLocationService] falling back to lastKnownPosition=$lastKnown');
      return lastKnown;
    } catch (e) {
      debugPrint('[DeviceLocationService] getLastKnownPosition failed: $e');
      return null;
    }
  }
}
