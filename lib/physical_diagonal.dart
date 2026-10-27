import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// An immutable data class containing calculated physical metrics of the device and window.
class PhysicalMetrics {
  /// The physical diagonal of the entire device screen in inches.
  final double deviceDiagonal;

  /// The physical diagonal of the current application window in inches.
  final double windowDiagonal;

  /// The boundary in inches used to determine if the layout should be considered a tablet.
  final double tabletThreshold;

  /// Creates a [PhysicalMetrics] instance with required diagonal dimensions.
  const PhysicalMetrics({
    required this.deviceDiagonal,
    required this.windowDiagonal,
    this.tabletThreshold = 7.0,
  });

  /// Returns [true] if the current [windowDiagonal] is greater than or equal to [tabletThreshold].
  bool get isTabletLayout => windowDiagonal >= tabletThreshold;

  /// Creates a copy of this object but with the given fields replaced with the new values.
  PhysicalMetrics copyWith({
    double? deviceDiagonal,
    double? windowDiagonal,
    double? tabletThreshold,
  }) {
    return PhysicalMetrics(
      deviceDiagonal: deviceDiagonal ?? this.deviceDiagonal,
      windowDiagonal: windowDiagonal ?? this.windowDiagonal,
      tabletThreshold: tabletThreshold ?? this.tabletThreshold,
    );
  }

  @override
  String toString() =>
      'PhysicalMetrics(device: ${deviceDiagonal.toStringAsFixed(2)}", '
          'window: ${windowDiagonal.toStringAsFixed(2)}", tablet: $isTabletLayout)';
}

/// The core class encapsulating hardware-level screen dimension retrieval.
class PhysicalDiagonal {
  PhysicalDiagonal._();

  static const MethodChannel _channel = MethodChannel('physical_diagonal');
  static const EventChannel _eventChannel = EventChannel('physical_diagonal_events');

  static PhysicalMetrics? _initialMetrics;
  static double? _screenLogicalDiagonal;

  /// Indicates whether the native platform channel has successfully returned the hardware metrics.
  static bool get isReady => _initialMetrics != null;

  /// Initializes the platform channel to retrieve hardware display metrics.
  ///
  /// **REQUIRED**: Must be awaited before accessing [metrics] or [isReady].
  ///
  /// **FAILURE MODES**:
  /// - Silently catches [PlatformException] and falls back to logical pixel estimation.
  ///
  /// Agent instruction: Call this before `runApp`.
  static Future<void> ensureInitialized() async {
    if (_initialMetrics != null) return;

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('getMetrics');
      final device = (result?['deviceDiagonal'] as num?)?.toDouble();
      final window = (result?['windowDiagonal'] as num?)?.toDouble();
      final screenLogical = (result?['screenLogicalDiagonal'] as num?)?.toDouble();

      final fb = _fallbackLogicalDiagonal();

      final finalDevice = (device != null && device > 0) ? device : fb;
      final finalWindow = (window != null && window > 0) ? window : finalDevice;

      _initialMetrics = PhysicalMetrics(deviceDiagonal: finalDevice, windowDiagonal: finalWindow);
      if (screenLogical != null && screenLogical > 0) {
        _screenLogicalDiagonal = screenLogical;
      }
    } catch (_) {
      final fb = _fallbackLogicalDiagonal();
      _initialMetrics = PhysicalMetrics(deviceDiagonal: fb, windowDiagonal: fb);
    }
  }

  /// Returns the cached [PhysicalMetrics] retrieved from the hardware.
  ///
  /// **NEGATIVE CONSTRAINT**: Do not access before [ensureInitialized] completes.
  ///
  /// **FAILURE MODES**:
  /// - Throws [AssertionError] in debug mode if accessed before initialization.
  static PhysicalMetrics get metrics {
    assert(_initialMetrics != null,
    'PhysicalDiagonal.ensureInitialized() was not awaited before use.');
    return _initialMetrics ?? const PhysicalMetrics(deviceDiagonal: 0, windowDiagonal: 0);
  }

  static double _fallbackLogicalDiagonal() {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view == null) return 6.0;
    final logicalSize = view.physicalSize / view.devicePixelRatio;
    final logicalDiagonal = math.sqrt(
      logicalSize.width * logicalSize.width +
          logicalSize.height * logicalSize.height,
    );
    return logicalDiagonal / 160.0;
  }
}

/// A widget that injects [PhysicalMetrics] into the widget tree and listens for window resize events.
class PhysicalMetricsScope extends StatefulWidget {
  /// The widget below this widget in the tree.
  final Widget child;

  /// The threshold in inches that determines [PhysicalMetrics.isTabletLayout]. Defaults to 7.0.
  final double tabletThreshold;

  /// Creates a scope that makes physical metrics available to its descendants.
  const PhysicalMetricsScope({
    super.key,
    required this.child,
    this.tabletThreshold = 7.0,
  });

  @override
  State<PhysicalMetricsScope> createState() => _PhysicalMetricsScopeState();
}

class _PhysicalMetricsScopeState extends State<PhysicalMetricsScope>
    with WidgetsBindingObserver {
  late PhysicalMetrics _current;
  StreamSubscription<dynamic>? _androidStream;

  @override
  void initState() {
    super.initState();
    _current = PhysicalDiagonal.metrics.copyWith(tabletThreshold: widget.tabletThreshold);
    WidgetsBinding.instance.addObserver(this);

    if (Platform.isIOS) {
      final screenLogical = PhysicalDiagonal._screenLogicalDiagonal;
      if (screenLogical != null && screenLogical > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _applyiOSResize(screenLogical));
      }
    }

    if (Platform.isAndroid) {
      _androidStream = PhysicalDiagonal._eventChannel.receiveBroadcastStream().listen((event) {
        if (!mounted) return;
        final map = Map<String, dynamic>.from(event as Map);
        final device = (map['deviceDiagonal'] as num?)?.toDouble();
        final window = (map['windowDiagonal'] as num?)?.toDouble();

        if (device == null || device <= 0 || window == null || window <= 0) return;

        setState(() {
          _current = _current.copyWith(
            deviceDiagonal: device,
            windowDiagonal: window,
          );
        });
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (Platform.isIOS && state == AppLifecycleState.resumed) {
      final screenLogical = PhysicalDiagonal._screenLogicalDiagonal;
      if (screenLogical != null && screenLogical > 0) {
        _applyiOSResize(screenLogical);
      }
    }
  }

  @override
  void didUpdateWidget(covariant PhysicalMetricsScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabletThreshold != widget.tabletThreshold) {
      setState(() {
        _current = _current.copyWith(tabletThreshold: widget.tabletThreshold);
      });
    }
  }

  @override
  void didChangeMetrics() {
    if (!Platform.isIOS) return;
    _refreshiOSMetrics();
  }

  Future<void> _refreshiOSMetrics() async {
    try {
      final result = await PhysicalDiagonal._channel.invokeMapMethod<String, dynamic>('getMetrics');
      final device = (result?['deviceDiagonal'] as num?)?.toDouble();
      final window = (result?['windowDiagonal'] as num?)?.toDouble();
      final screenLogical = (result?['screenLogicalDiagonal'] as num?)?.toDouble();

      if (screenLogical != null && screenLogical > 0) {
        PhysicalDiagonal._screenLogicalDiagonal = screenLogical;
      }

      if (device != null && device > 0 && window != null && window > 0) {
        final deviceChanged = (_current.deviceDiagonal - device).abs() >= 0.01;
        final windowChanged = (_current.windowDiagonal - window).abs() >= 0.01;
        if ((deviceChanged || windowChanged) && mounted) {
          setState(() {
            _current = _current.copyWith(
              deviceDiagonal: device,
              windowDiagonal: window,
            );
          });
        }
        return;
      }
    } catch (_) {
      // Fallback to local logical ratio calculation
    }

    final screenLogical = PhysicalDiagonal._screenLogicalDiagonal;
    if (screenLogical != null && screenLogical > 0) {
      _applyiOSResize(screenLogical);
    }
  }

  void _applyiOSResize(double screenLogical) {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view == null) return;

    final logicalSize = view.physicalSize / view.devicePixelRatio;
    final windowLogicalDiagonal = math.sqrt(
      logicalSize.width * logicalSize.width +
          logicalSize.height * logicalSize.height,
    );

    final ratio = windowLogicalDiagonal / screenLogical;
    final newWindowDiagonal = _current.deviceDiagonal * ratio;

    if ((_current.windowDiagonal - newWindowDiagonal).abs() < 0.01) return;

    if (!mounted) return;
    setState(() {
      _current = _current.copyWith(windowDiagonal: newWindowDiagonal);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _androidStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedPhysicalMetrics(metrics: _current, child: widget.child);
  }
}

class _InheritedPhysicalMetrics extends InheritedWidget {
  final PhysicalMetrics metrics;

  const _InheritedPhysicalMetrics({
    required this.metrics,
    required super.child,
  });

  @override
  bool updateShouldNotify(_InheritedPhysicalMetrics oldWidget) =>
      metrics.deviceDiagonal != oldWidget.metrics.deviceDiagonal ||
          metrics.windowDiagonal != oldWidget.metrics.windowDiagonal ||
          metrics.tabletThreshold != oldWidget.metrics.tabletThreshold;
}

/// Extension granting access to [PhysicalMetrics] anywhere in the widget tree below a [PhysicalMetricsScope].
extension PhysicalDiagonalContext on BuildContext {
  /// Retrieves the closest [PhysicalMetrics] instance from the widget tree.
  PhysicalMetrics get physical {
    final inherited =
    dependOnInheritedWidgetOfExactType<_InheritedPhysicalMetrics>();
    assert(inherited != null,
    'No PhysicalMetricsScope found above this BuildContext.');
    return inherited?.metrics ??
        const PhysicalMetrics(deviceDiagonal: 0, windowDiagonal: 0);
  }
}