/// A point on the map: the delivery pin of an address (WGS 84 degrees).
typedef GeoPin = ({double latitude, double longitude});

/// Tashkent centre, where the map opens when an address has no pin.
const GeoPin tashkentCentre = (latitude: 41.3111, longitude: 69.2797);

double _round6(double v) => (v * 1e6).roundToDouble() / 1e6;

/// Both coordinates finite and in range → a pin rounded to 6 decimals (the
/// API's precision); anything else, including half a pin, → null. Accepts
/// numbers and numeric strings.
GeoPin? toPin(Object? latitude, Object? longitude) {
  double? read(Object? v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}'.trim());
  final lat = read(latitude), lng = read(longitude);
  if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) return null;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
  return (latitude: _round6(lat), longitude: _round6(lng));
}

/// Longitude wrapped into −180…180 (a map dragged around the world).
double wrapLongitude(double lng) {
  final wrapped = ((lng + 180) % 360 + 360) % 360 - 180;
  return wrapped == -180 && lng > 0 ? 180 : wrapped;
}

/// "41.311100, 69.279700"
String formatPin(GeoPin pin) =>
    '${pin.latitude.toStringAsFixed(6)}, ${pin.longitude.toStringAsFixed(6)}';
