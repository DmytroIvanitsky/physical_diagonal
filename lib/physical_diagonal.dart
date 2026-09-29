import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class PhysicalMetrics {
  final double deviceDiagonal;
  final double windowDiagonal;
  final double tabletThreshold;

  const PhysicalMetrics({
    required this.deviceDiagonal,
    required this.windowDiagonal,
    this.tabletThreshold = 7.0,
  });

  bool get isTabletLayout => windowDiagonal >= tabletThreshold;

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

class PhysicalDiagonal {
  PhysicalDiagonal._();

  static const MethodChannel _channel = MethodChannel('physical_diagonal');
  static const EventChannel _eventChannel = EventChannel('physical_diagonal_events');

  static PhysicalMetrics? _initialMetrics;
  static double? _screenLogicalDiagonal;

  static bool get isReady => _initialMetrics != null;

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

class PhysicalMetricsScope extends StatefulWidget {
  final Widget child;
  final double tabletThreshold;

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

extension PhysicalDiagonalContext on BuildContext {
  PhysicalMetrics get physical {
    final inherited =
        dependOnInheritedWidgetOfExactType<_InheritedPhysicalMetrics>();
    assert(inherited != null,
        'No PhysicalMetricsScope found above this BuildContext.');
    return inherited?.metrics ??
        const PhysicalMetrics(deviceDiagonal: 0, windowDiagonal: 0);
  }
}