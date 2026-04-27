import 'map_js_checker.dart';

Future<MapJsCheckResult> checkGoogleMapsLibraryImpl() async {
  return const MapJsCheckResult(hasGoogleMaps: true);
}
