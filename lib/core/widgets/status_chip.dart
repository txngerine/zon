import 'package:flutter/material.dart';

import '../../domain/models/download.dart';
import '../theme/app_type.dart';
import '../theme/zon_palette.dart';

/// State label for a download.
///
/// States are differentiated with typography, iconography and contrast only —
/// never with colour, in keeping with the monochrome identity.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.compact = false});

  final DownloadStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final Color background;
    final Color border;
    final Color foreground;

    switch (status) {
      case DownloadStatus.downloading:
        background = palette.textPrimary.withValues(alpha: 0.10);
        border = palette.textPrimary.withValues(alpha: 0.22);
        foreground = palette.textPrimary;
      case DownloadStatus.verifying:
        background = palette.surfaceHighest;
        border = palette.border;
        foreground = palette.textSecondary;
      case DownloadStatus.completed:
        background = palette.textPrimary.withValues(alpha: 0.14);
        border = palette.textPrimary.withValues(alpha: 0.28);
        foreground = palette.textPrimary;
      case DownloadStatus.failed:
        background = palette.surfaceHighest;
        border = palette.textPrimary.withValues(alpha: 0.34);
        foreground = palette.textPrimary;
      case DownloadStatus.paused:
        background = Colors.transparent;
        border = palette.borderStrong;
        foreground = palette.textSecondary;
      case DownloadStatus.queued:
        background = Colors.transparent;
        border = palette.border;
        foreground = palette.textMuted;
      case DownloadStatus.cancelled:
        background = Colors.transparent;
        border = palette.border;
        foreground = palette.textMuted;
    }

    return Container(
      height: compact ? 20 : 23,
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Leading(status: status, color: foreground, size: compact ? 10 : 11),
          const SizedBox(width: 5),
          Text(
            status.name.toUpperCase(),
            style: AppType.eyebrow(
              foreground,
              size: compact ? 8.5 : 9.5,
              spacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _Leading extends StatelessWidget {
  const _Leading({
    required this.status,
    required this.color,
    required this.size,
  });

  final DownloadStatus status;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case DownloadStatus.downloading:
        return _PulsingDot(color: color, size: size);
      case DownloadStatus.verifying:
        return _ArcSpinner(color: color, size: size);
      case DownloadStatus.completed:
        return Icon(Icons.check_rounded, size: size + 2, color: color);
      case DownloadStatus.failed:
        return Icon(Icons.priority_high_rounded, size: size + 2, color: color);
      case DownloadStatus.paused:
        return Icon(Icons.pause_rounded, size: size + 2, color: color);
      case DownloadStatus.queued:
        return Icon(Icons.schedule_rounded, size: size + 2, color: color);
      case DownloadStatus.cancelled:
        return Icon(Icons.block_rounded, size: size + 1, color: color);
    }
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
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
        begin: 0.35,
        end: 1,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

class _ArcSpinner extends StatefulWidget {
  const _ArcSpinner({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  State<_ArcSpinner> createState() => _ArcSpinnerState();
}

class _ArcSpinnerState extends State<_ArcSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Transform.rotate(
        angle: _controller.value * 6.283,
        child: CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _ArcPainter(color: widget.color),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(0.8), -1.4, 4.2, false, paint);
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) => oldDelegate.color != color;
}
