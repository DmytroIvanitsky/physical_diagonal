import 'package:flutter/material.dart';
import 'package:physical_diagonal/physical_diagonal.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Must complete before runApp: the first frame is then built with real
  // metrics instead of an empty placeholder.
  await PhysicalDiagonal.ensureInitialized();
  runApp(const ExampleApp());
}

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  double _threshold = 7.0;

  @override
  Widget build(BuildContext context) {
    // The scope sits above MaterialApp so every route can read context.physical.
    return PhysicalMetricsScope(
      tabletThreshold: _threshold,
      child: MaterialApp(
        title: 'physical_diagonal example',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: HomePage(
          threshold: _threshold,
          onThresholdChanged: (value) => setState(() => _threshold = value),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.threshold,
    required this.onThresholdChanged,
  });

  final double threshold;
  final ValueChanged<double> onThresholdChanged;

  @override
  Widget build(BuildContext context) {
    // Registers a dependency: this widget rebuilds when the window or
    // device diagonal (or the threshold) changes.
    final metrics = context.physical;

    final metricsCard = _MetricsCard(metrics: metrics);
    final thresholdCard = _ThresholdCard(
      threshold: threshold,
      onChanged: onThresholdChanged,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('physical_diagonal')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: metrics.isTabletLayout
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: metricsCard),
                    const SizedBox(width: 16),
                    Expanded(child: thresholdCard),
                  ],
                )
              : Column(
                  children: [
                    metricsCard,
                    const SizedBox(height: 16),
                    thresholdCard,
                  ],
                ),
        ),
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  const _MetricsCard({required this.metrics});

  final PhysicalMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Screen metrics', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            _MetricRow(
              label: 'Device diagonal',
              value: '${metrics.deviceDiagonal.toStringAsFixed(2)}"',
            ),
            _MetricRow(
              label: 'Window diagonal',
              value: '${metrics.windowDiagonal.toStringAsFixed(2)}"',
            ),
            _MetricRow(
              label: 'Tablet threshold',
              value: '${metrics.tabletThreshold.toStringAsFixed(1)}"',
            ),
            const SizedBox(height: 12),
            Chip(
              avatar: Icon(
                metrics.isTabletLayout ? Icons.tablet_mac : Icons.phone_iphone,
              ),
              label: Text(
                metrics.isTabletLayout ? 'Tablet layout' : 'Phone layout',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ThresholdCard extends StatelessWidget {
  const _ThresholdCard({required this.threshold, required this.onChanged});

  final double threshold;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tablet threshold', style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'isTabletLayout is true when the window diagonal is at least '
              '${threshold.toStringAsFixed(1)}".',
            ),
            Slider(
              value: threshold,
              min: 4,
              max: 13,
              divisions: 18,
              label: '${threshold.toStringAsFixed(1)}"',
              onChanged: onChanged,
            ),
            const SizedBox(height: 8),
            Text(
              'Resize the window (split-screen, Stage Manager, folding) to '
              'watch the window diagonal change while the device diagonal '
              'stays fixed.',
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
