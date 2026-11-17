import 'package:flutter_test/flutter_test.dart';
import 'package:glow_derma/core/format/geo.dart';

void main() {
  group('toPin', () {
    test('numbers and numeric strings', () {
      expect(toPin(41.2854, 69.2035), (latitude: 41.2854, longitude: 69.2035));
      expect(toPin(' 41.5 ', '69'), (latitude: 41.5, longitude: 69.0));
      expect(toPin(41, 69), (latitude: 41.0, longitude: 69.0));
    });

    test('half a pin or garbage is no pin', () {
      expect(toPin(41.3, null), isNull);
      expect(toPin(null, 69.2), isNull);
      expect(toPin(null, null), isNull);
      expect(toPin('', ''), isNull);
      expect(toPin('abc', 69), isNull);
      expect(toPin(double.nan, 69), isNull);
      expect(toPin(41, double.infinity), isNull);
    });

    test('out of range', () {
      expect(toPin(90.0001, 0), isNull);
      expect(toPin(-90.0001, 0), isNull);
      expect(toPin(0, 180.0001), isNull);
      expect(toPin(0, -180.5), isNull);
      expect(toPin(90, 180), (latitude: 90.0, longitude: 180.0));
      expect(toPin(-90, -180), (latitude: -90.0, longitude: -180.0));
    });

    test('rounds to 6 decimals', () {
      expect(toPin(41.31110049, 69.27970051), (
        latitude: 41.3111,
        longitude: 69.279701,
      ));
      expect(toPin('41.1234565', 0)!.latitude, closeTo(41.123457, 1e-9));
    });
  });

  test('wrapLongitude', () {
    expect(wrapLongitude(69.2797), closeTo(69.2797, 1e-9));
    expect(wrapLongitude(180), 180);
    expect(wrapLongitude(-180), -180);
    expect(wrapLongitude(190), closeTo(-170, 1e-9));
    expect(wrapLongitude(-190), closeTo(170, 1e-9));
    expect(wrapLongitude(69.2797 + 360), closeTo(69.2797, 1e-9));
    expect(wrapLongitude(69.2797 - 720), closeTo(69.2797, 1e-9));
    expect(wrapLongitude(540), 180);
  });

  test('formatPin', () {
    expect(formatPin(tashkentCentre), '41.311100, 69.279700');
    expect(
      formatPin((latitude: -0.5, longitude: 120.123456)),
      '-0.500000, 120.123456',
    );
  });
}
