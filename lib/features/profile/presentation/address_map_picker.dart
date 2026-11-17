import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/gd_colors.dart';
import '../../../app/theme/gd_theme.dart';
import '../../../core/config/app_config.dart';
import '../../../core/format/geo.dart';
import 'address_text.dart';

/// Zoom of a map opened on a saved pin: close enough to see the building.
const double pinnedMapZoom = 16;

/// Zoom of a map opened without a pin (all of Tashkent).
const double defaultMapZoom = 12;

/// Zoom after "Joylashuvimni aniqlash".
const double locatedMapZoom = 17;

const double _minZoom = 3;
const double _maxZoom = 19;

/// Whether the map loads its raster tiles. Widget tests override it with
/// `false` so nothing reaches the network.
final addressMapTilesProvider = Provider<bool>((ref) => true);

/// Why "Joylashuvimni aniqlash" found nothing.
class LocateFailure implements Exception {
  const LocateFailure({required this.denied});

  /// The customer (or the system) refused location access.
  final bool denied;

  @override
  String toString() => 'LocateFailure(denied: $denied)';
}

/// The device's current position (geolocator). Overridden in tests.
class DeviceLocator {
  const DeviceLocator();

  /// Throws [LocateFailure]; never anything else.
  Future<GeoPin> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocateFailure(denied: false);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const LocateFailure(denied: true);
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final pin = toPin(position.latitude, position.longitude);
      if (pin == null) throw const LocateFailure(denied: false);
      return pin;
    } on LocateFailure {
      rethrow;
    } on PermissionDeniedException {
      throw const LocateFailure(denied: true);
    } on Object {
      // Service off, timeout, no plugin (web without geolocation)…
      throw const LocateFailure(denied: false);
    }
  }
}

final deviceLocatorProvider = Provider<DeviceLocator>(
  (ref) => const DeviceLocator(),
);

enum _Locate { idle, locating, denied, failed }

/// The delivery point of an address (Yandex courier delivery needs it):
/// OpenStreetMap tiles in flutter_map. A tap sets the pin, a long press on
/// the marker drags it, "Xarita markaziga qo‘yish" pins the map centre and
/// "Joylashuvimni aniqlash" uses the device location. The map owns its pan
/// and pinch gestures, so dragging it never scrolls the form around it.
class AddressMapPicker extends ConsumerStatefulWidget {
  const AddressMapPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.error,
    this.needsPin = false,
    this.height = 260,
  });

  final GeoPin? value;
  final ValueChanged<GeoPin?> onChanged;

  /// A field error of the save (`latitude` / `longitude`).
  final String? error;

  /// No BTS regions to choose from: the pin is what makes delivery possible.
  final bool needsPin;
  final double height;

  @override
  ConsumerState<AddressMapPicker> createState() => _AddressMapPickerState();
}

class _AddressMapPickerState extends ConsumerState<AddressMapPicker> {
  final _controller = MapController();
  final _mapKey = GlobalKey();
  bool _ready = false;
  bool _tilesFailed = false;
  _Locate _locate = _Locate.idle;

  /// The marker while it is being dragged (committed on release).
  GeoPin? _dragPin;
  Offset _grab = Offset.zero;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _choose(LatLng point) {
    final pin = toPin(point.latitude, wrapLongitude(point.longitude));
    if (pin != null) widget.onChanged(pin);
  }

  Offset? _local(Offset global) {
    final box = _mapKey.currentContext?.findRenderObject();
    return box is RenderBox ? box.globalToLocal(global) : null;
  }

  void _dragStart(LongPressStartDetails d) {
    final pin = widget.value;
    final at = _local(d.globalPosition);
    if (!_ready || pin == null || at == null) return;
    final point = _controller.camera.latLngToScreenOffset(
      LatLng(pin.latitude, pin.longitude),
    );
    setState(() {
      _grab = point - at;
      _dragPin = pin;
    });
  }

  void _dragMove(LongPressMoveUpdateDetails d) {
    final at = _local(d.globalPosition);
    if (_dragPin == null || at == null) return;
    final p = _controller.camera.screenOffsetToLatLng(at + _grab);
    final pin = toPin(p.latitude, wrapLongitude(p.longitude));
    if (pin != null) setState(() => _dragPin = pin);
  }

  void _dragEnd(LongPressEndDetails _) {
    final pin = _dragPin;
    if (pin == null) return;
    setState(() => _dragPin = null);
    widget.onChanged(pin);
  }

  void _pinCentre() {
    if (_ready) _choose(_controller.camera.center);
  }

  void _zoom(double by) {
    if (!_ready) return;
    final camera = _controller.camera;
    _controller.move(
      camera.center,
      (camera.zoom + by).clamp(_minZoom, _maxZoom).toDouble(),
    );
  }

  Future<void> _findMe() async {
    setState(() => _locate = _Locate.locating);
    try {
      final pin = await ref.read(deviceLocatorProvider).locate();
      if (!mounted) return;
      setState(() => _locate = _Locate.idle);
      widget.onChanged(pin);
      if (_ready) {
        _controller.move(
          LatLng(pin.latitude, pin.longitude),
          math.max(_controller.camera.zoom, locatedMapZoom),
        );
      }
    } on LocateFailure catch (e) {
      if (mounted) {
        setState(() => _locate = e.denied ? _Locate.denied : _Locate.failed);
      }
    } on Object {
      if (mounted) setState(() => _locate = _Locate.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final t = context.gdText;
    final value = widget.value;
    final shown = _dragPin ?? value;
    final tiles = ref.watch(addressMapTilesProvider);
    final start = value ?? tashkentCentre;
    final locateNote = switch (_locate) {
      _Locate.idle => null,
      _Locate.locating => AddressMapText.locating,
      _Locate.denied => AddressMapText.locateDenied,
      _Locate.failed => AddressMapText.locateFailed,
    };

    final map = FlutterMap(
      key: _mapKey,
      mapController: _controller,
      options: MapOptions(
        initialCenter: LatLng(start.latitude, start.longitude),
        initialZoom: value == null ? defaultMapZoom : pinnedMapZoom,
        minZoom: _minZoom,
        maxZoom: _maxZoom,
        backgroundColor: c.imageWell,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () {
          if (mounted) setState(() => _ready = true);
        },
        onTap: (_, point) => _choose(point),
        onLongPress: (_, point) => _choose(point),
      ),
      children: [
        if (tiles)
          TileLayer(
            urlTemplate: AppConfig.mapTileUrl,
            userAgentPackageName: 'uz.glowderma.app',
            maxNativeZoom: 19,
            errorTileCallback: (_, _, _) {
              if (!_tilesFailed && mounted) {
                setState(() => _tilesFailed = true);
              }
            },
          ),
        if (shown != null)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(shown.latitude, shown.longitude),
                width: 40,
                height: 48,
                alignment: Alignment.topCenter,
                child: Semantics(
                  label: AddressMapText.marker.of(context),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onLongPressStart: _dragStart,
                    onLongPressMoveUpdate: _dragMove,
                    onLongPressEnd: _dragEnd,
                    child: Icon(
                      Icons.location_on,
                      key: const ValueKey('address.map.marker'),
                      size: 44,
                      color: c.goldInk,
                      shadows: const [
                        Shadow(color: Color(0x55000000), blurRadius: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        const _Attribution(),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(AddressMapText.title.of(context), style: t.label),
        const SizedBox(height: 4),
        Text(
          (widget.needsPin && value == null
                  ? AddressMapText.hintNoRegions
                  : AddressMapText.hint)
              .of(context),
          style: t.caption,
        ),
        const SizedBox(height: 8),
        Semantics(
          identifier: 'address.map',
          label: AddressMapText.region.of(context),
          container: true,
          child: Container(
            height: widget.height,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: c.imageWell,
              borderRadius: BorderRadius.circular(GdRadius.md),
              border: Border.all(
                color: widget.error != null ? c.danger : c.line,
                width: 1.5,
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(child: map),
                // The centre mark for "Xarita markaziga qo‘yish".
                Center(
                  child: IgnorePointer(
                    child: Icon(
                      Icons.add,
                      size: 22,
                      color: c.ink.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Column(
                    children: [
                      _ZoomButton(
                        icon: Icons.add_rounded,
                        tooltip: AddressMapText.zoomIn.of(context),
                        semanticsId: 'address.map.zoomIn',
                        onPressed: _ready ? () => _zoom(1) : null,
                      ),
                      const SizedBox(height: 6),
                      _ZoomButton(
                        icon: Icons.remove_rounded,
                        tooltip: AddressMapText.zoomOut.of(context),
                        semanticsId: 'address.map.zoomOut',
                        onPressed: _ready ? () => _zoom(-1) : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 18,
              color: shown != null ? c.goldInk : c.inkMuted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                shown != null
                    ? '${AddressMapText.chosen.of(context)}: ${formatPin(shown)}'
                    : AddressMapText.none.of(context),
                style: t.bodySm.copyWith(
                  color: shown != null ? c.ink : c.inkMuted,
                ),
              ),
            ),
          ],
        ),
        if (widget.error != null) ...[
          const SizedBox(height: 4),
          Semantics(
            liveRegion: true,
            child: Text(
              widget.error!,
              style: t.bodySm.copyWith(
                color: c.dangerStrong,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (locateNote != null) ...[
          const SizedBox(height: 4),
          Semantics(
            liveRegion: true,
            child: Text(locateNote.of(context), style: t.caption),
          ),
        ],
        if (_tilesFailed) ...[
          const SizedBox(height: 4),
          Text(AddressMapText.unavailable.of(context), style: t.caption),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MapAction(
              icon: Icons.my_location_rounded,
              label: AddressMapText.locate.of(context),
              semanticsId: 'address.map.locate',
              busy: _locate == _Locate.locating,
              onPressed: _locate == _Locate.locating ? null : _findMe,
            ),
            _MapAction(
              icon: Icons.add_location_alt_outlined,
              label: AddressMapText.center.of(context),
              semanticsId: 'address.map.center',
              onPressed: _ready ? _pinCentre : null,
            ),
            if (value != null)
              _MapAction(
                icon: Icons.close_rounded,
                label: AddressMapText.clear.of(context),
                semanticsId: 'address.map.clear',
                onPressed: () => widget.onChanged(null),
              ),
          ],
        ),
      ],
    );
  }
}

class _MapAction extends StatelessWidget {
  const _MapAction({
    required this.icon,
    required this.label,
    required this.semanticsId,
    required this.onPressed,
    this.busy = false,
  });
  final IconData icon;
  final String label;
  final String semanticsId;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => Semantics(
    identifier: semanticsId,
    button: true,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        visualDensity: VisualDensity.compact,
      ),
      icon: busy
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 18),
      label: Text(label),
    ),
  );
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.icon,
    required this.tooltip,
    required this.semanticsId,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final String semanticsId;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    return Semantics(
      identifier: semanticsId,
      button: true,
      child: Material(
        color: c.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GdRadius.sm),
          side: BorderSide(color: c.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, size: 20, color: c.ink),
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

/// The ODbL credit the tiles require wherever the map is shown.
class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    return Align(
      alignment: Alignment.bottomRight,
      child: GestureDetector(
        onTap: () => unawaited(
          launchUrl(
            Uri.parse('https://www.openstreetmap.org/copyright'),
            mode: LaunchMode.externalApplication,
          ).catchError((_) => false),
        ),
        child: ColoredBox(
          color: c.surface.withValues(alpha: 0.85),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            child: Text(
              '© OpenStreetMap contributors',
              style: context.gdText.caption.copyWith(
                fontSize: 10,
                color: c.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
