import 'map_js_checker_stub.dart'
    if (dart.library.js_interop) 'map_js_checker_web.dart';

class MapJsCheckResult {
  final bool hasGoogleMaps;
  final String? error;

  const MapJsCheckResult({
    required this.hasGoogleMaps,
    this.error,
  });
}

Future<MapJsCheckResult> checkGoogleMapsLibrary() => checkGoogleMapsLibraryImpl();
