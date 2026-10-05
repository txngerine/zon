import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_type.dart';
import '../../core/theme/zon_palette.dart';
import '../../core/widgets/zon_card.dart';
import '../../data/app_state.dart';

/// Compact transfer analytics: current rate, peak, average and a monochrome
/// line graph that animates smoothly as samples arrive.
class SpeedPanel extends StatelessWidget {
  const SpeedPanel({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final live = state.activeCount > 0;

    return ZonCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 620;

          final header = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    'DOWNLOAD SPEED',
                    style: AppType.eyebrow(palette.textMuted),
                  ),
                  const SizedBox(width: 8),
                  if (live) ...[
                    const _LiveDot(),
                    const SizedBox(width: 6),
                    Text(
                      'LIVE',
                      style: AppType.eyebrow(palette.textSecondary, size: 8.5),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _format(state.totalSpeed),
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1,
                  fontFeatures: AppType.tabular,
                  height: 1,
                ),
              ),
            ],
          );

          final graph = Padding(
            padding: narrow
                ? const EdgeInsets.only(top: 16)
                : const EdgeInsets.symmetric(horizontal: 24),
            child: SpeedGraph(
              samples: state.speedSamples,
              height: narrow ? 84 : 104,
            ),
          );

          final stats = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatBlock(label: 'PEAK', value: _format(state.peakSpeed)),
              const SizedBox(height: 14),
              _StatBlock(label: 'AVERAGE', value: _format(state.averageSpeed)),
            ],
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                graph,
                Row(
                  children: [
                    Expanded(
                      child: _StatBlock(
                        label: 'PEAK',
                        value: _format(state.peakSpeed),
                      ),
                    ),
                    Expanded(
                      child: _StatBlock(
                        label: 'AVERAGE',
                        value: _format(state.averageSpeed),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              header,
              Expanded(child: graph),
              SizedBox(width: 120, child: stats),
            ],
          );
        },
      ),
    );
  }

  static String _format(double bytesPerSecond) {
    if (bytesPerSecond < 1024) return '0 B/s';
    const units = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
    var value = bytesPerSecond;
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final text = value >= 100
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$text ${units[unit]}';
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppType.eyebrow(palette.textMuted, size: 8.5, spacing: 1.4),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            fontFeatures: AppType.tabular,
          ),
        ),
      ],
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.3,
        end: 1,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: context.palette.textPrimary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Smoothly animated monochrome line chart.
class SpeedGraph extends StatefulWidget {
  const SpeedGraph({super.key, required this.samples, this.height = 100});

  final List<double> samples;
  final double height;

  @override
  State<SpeedGraph> createState() => _SpeedGraphState();
}

class _SpeedGraphState extends State<SpeedGraph>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<double> _from = const [];
  List<double> _to = const [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _to = List<double>.of(widget.samples);
    _from = List<double>.of(_to);
  }

  @override
  void didUpdateWidget(SpeedGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.samples, widget.samples)) {
      _from = _current();
      _to = List<double>.of(widget.samples);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<double> _current() {
    final t = Curves.easeOutCubic.transform(_controller.value);
    final length = math.max(_from.length, _to.length);
    final a = _normalized(_from, length);
    final b = _normalized(_to, length);
    return [for (var i = 0; i < length; i++) a[i] + (b[i] - a[i]) * t];
  }

  static List<double> _normalized(List<double> values, int length) {
    if (values.length == length) return values;
    if (values.length > length) return values.sublist(values.length - length);
    return [...values, for (var i = values.length; i < length; i++) 0.0];
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size(double.infinity, widget.height),
          painter: _SpeedGraphPainter(
            values: _controller.isAnimating ? _current() : _to,
            line: palette.textPrimary,
            grid: palette.border,
          ),
        );
      },
    );
  }
}

class _SpeedGraphPainter extends CustomPainter {
  _SpeedGraphPainter({
    required this.values,
    required this.line,
    required this.grid,
  });

  final List<double> values;
  final Color line;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final gridPaint = Paint()
      ..color = grid.withValues(alpha: 0.7)
      ..strokeWidth = 0.8;

    for (var i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (values.length < 2) return;

    final maxValue = math.max(values.reduce(math.max), 1024.0);
    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(
          size.width * i / (values.length - 1),
          size.height - (values[i] / maxValue) * (size.height - 8) - 4,
        ),
    ];

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
      path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);

    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [line.withValues(alpha: 0.16), line.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = line.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final last = points.last;
    canvas.drawCircle(last, 7, Paint()..color = line.withValues(alpha: 0.14));
    canvas.drawCircle(last, 3, Paint()..color = line);
  }

  @override
  bool shouldRepaint(_SpeedGraphPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.line != line ||
      oldDelegate.grid != grid;
}

/// Small sparkline used inside the details panel.
class MiniSpeedGraph extends StatelessWidget {
  const MiniSpeedGraph({super.key, required this.state, this.height = 64});

  final AppState state;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: SpeedGraph(samples: state.speedSamples, height: height),
    );
  }
}
