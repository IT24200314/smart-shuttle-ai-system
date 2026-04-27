// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:js' as js;

import 'map_js_checker.dart';

Future<MapJsCheckResult> checkGoogleMapsLibraryImpl() async {
  try {
    final googleExists = js.context.hasProperty('google');
    if (!googleExists) {
      return const MapJsCheckResult(
        hasGoogleMaps: false,
        error: 'Google Maps JS SDK not found. Check your API key and connection.',
      );
    }

    final google = js.context['google'];
    final mapsExists = google != null && google.hasProperty('maps');
    if (!mapsExists) {
      return const MapJsCheckResult(
        hasGoogleMaps: false,
        error: 'Google Maps JS SDK loaded without google.maps.',
      );
    }

    return const MapJsCheckResult(hasGoogleMaps: true);
  } catch (error) {
    return MapJsCheckResult(
      hasGoogleMaps: false,
      error: error.toString(),
    );
  }
}
